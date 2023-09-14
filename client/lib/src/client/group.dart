/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */
import 'package:object_key/object_key.dart';

import '../dim_common.dart';
import 'messenger.dart';

///  This is for sending group message, or managing group members
class GroupManager implements GroupDataSource {
  factory GroupManager() => _instance;
  static final GroupManager _instance = GroupManager._internal();
  GroupManager._internal() {
    messenger = null;
  }

  final Map<ID, ID>         _cachedGroupFounders = {};
  final Map<ID, ID>           _cachedGroupOwners = {};
  final Map<ID, List<ID>>    _cachedGroupMembers = {};
  final Map<ID, List<ID>> _cachedGroupAssistants = {};
  final List<ID>              _defaultAssistants = [];

  ClientMessenger? messenger;

  // private
  CommonFacebook? get facebook => messenger?.facebook;

  // private
  Future<User?> get currentUser async => await facebook?.currentUser;

  ///  Send group message content
  ///
  /// @param content - message content
  /// @return false on no bots found
  Future<bool> sendContent(Content content, ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    ID? gid = content.group;
    if (gid == null) {
      content.group = group;
    } else if (gid != group) {
      throw Exception('group ID not match: $gid, $group');
    }
    List<ID> assistants = await getAssistants(group);
    Pair<InstantMessage, ReliableMessage?> result;
    for (ID bot in assistants) {
      // send to any bot
      result = await messenger!.sendContent(content, sender: null, receiver: bot);
      if (result.second != null) {
        // only send to one bot, let the bot to split and
        // forward this message to all members
        return true;
      }
    }
    return false;
  }

  // private
  Future<void> sendCommand(Command content, {ID? receiver, List<ID>? members}) async {
    if (receiver != null) {
      await messenger!.sendContent(content, sender: null, receiver: receiver);
    }
    if (members != null) {
      ID? sender = (await currentUser)?.identifier;
      for (ID item in members) {
        await messenger!.sendContent(content, sender: sender, receiver: item);
      }
    }
  }


  ///  Invite new members to this group
  ///  (only existed member/assistant can do this)
  ///
  /// @param newMembers - new members ID list
  /// @return true on success
  Future<bool> invite(ID group, {ID? member, List<ID>? members}) async {
    assert(group.isGroup, 'group ID error: $group');
    List<ID> newMembers = members ?? [member!];

    // TODO: make sure group meta exists
    // TODO: make sure current user is a member

    // 0. build 'meta/document' command
    Meta? meta = await getMeta(group);
    if (meta == null) {
      throw Exception('failed to get meta for group: $group');
    }
    Document? doc = await getDocument(group, "*");
    Command command;
    if (doc == null) {
      // empty document
      command = MetaCommand.response(group, meta);
    } else {
      command = DocumentCommand.response(group, meta, doc);
    }
    List<ID> bots = await getAssistants(group);
    // 1. send 'meta/document' command
    await sendCommand(command, members: bots);                // to all assistants

    // 2. update local members and notice all bots & members
    members = await getMembers(group);
    if (members.length <= 2) { // new group?
      // 2.0. update local storage
      members = await addMembers(newMembers, group);
      // 2.1. send 'meta/document' command
      await sendCommand(command, members: members);         // to all members
      // 2.2. send 'invite' command with all members
      command = GroupCommand.invite(group, members: members);
      await sendCommand(command, members: bots);            // to group assistants
      await sendCommand(command, members: members);         // to all members
    } else {
      // 2.1. send 'meta/document' command
      // sendCommand(command, members: members);            // to old members
      await sendCommand(command, members: newMembers);      // to new members
      // 2.2. send 'invite' command with new members only
      command = GroupCommand.invite(group, members: newMembers);
      await sendCommand(command, members: bots);            // to group assistants
      await sendCommand(command, members: members);         // to old members
      // 2.3. update local storage
      members = await addMembers(newMembers, group);
      // 2.4. send 'invite' command with all members
      command = GroupCommand.invite(group, members: members);
      await sendCommand(command, members: newMembers);      // to new members
    }

    return true;
  }

  ///  Expel members from this group
  ///  (only group owner/assistant can do this)
  ///
  /// @param outMembers - existed member ID list
  /// @return true on success
  Future<bool> expel(ID group, {ID? member, List<ID>? members}) async {
    assert(group.isGroup, 'group ID error: $group');
    List<ID> outMembers = members ?? [member!];
    ID? owner = await getOwner(group);
    List<ID> bots = await getAssistants(group);

    // TODO: make sure group meta exists
    // TODO: make sure current user is the owner

    // 0. check permission
    for (ID assistant in bots) {
      if (outMembers.contains(assistant)) {
        throw Exception('Cannot expel group assistant: $assistant');
      }
    }
    if (outMembers.contains(owner)) {
      throw Exception('Cannot expel group owner: $owner');
    }

    // 1. update local storage
    members = await removeMembers(outMembers, group);

    // 2. send 'expel' command
    Command command = GroupCommand.expel(group, members: outMembers);
    await sendCommand(command, members: bots);        // to assistants
    await sendCommand(command, members: members);     // to new members
    await sendCommand(command, members: outMembers);  // to expelled members

    return true;
  }

  ///  Quit from this group
  ///  (only group member can do this)
  ///
  /// @return true on success
  Future<bool> quit(ID group) async {
    assert(group.isGroup, 'group ID error: $group');

    User? user = await currentUser;
    if (user == null) {
      throw Exception('failed to get current user');
    }
    ID me = user.identifier;

    ID? owner = await getOwner(group);
    List<ID> bots = await getAssistants(group);
    List<ID> members = await getMembers(group);

    // 0. check permission
    if (bots.contains(me)) {
      throw Exception('group assistant cannot quit: $me, group: $group');
    } else if (me == owner) {
      throw Exception('group owner cannot quit: $owner, group: $group');
    }

    // 1. update local storage
    bool ok = false;
    if (members.remove(me)) {
      ok = await saveMembers(members, group);
      //} else {
      //    // not a member now
      //    return false;
    }

    // 2. send 'quit' command
    Command command = GroupCommand.quit(group);
    await sendCommand(command, members: bots);     // to assistants
    await sendCommand(command, members: members);  // to new members

    return ok;
  }

  ///  Query group info
  ///
  /// @return false on error
  Future<bool> query(ID group) async {
    return await messenger!.queryMembers(group);
  }

  //-------- Data Source

  @override
  Future<Meta?> getMeta(ID identifier) async =>
      await facebook?.getMeta(identifier);

  @override
  Future<Document?> getDocument(ID identifier, String? docType) async =>
      await facebook?.getDocument(identifier, docType);

  @override
  Future<ID?> getFounder(ID group) async {
    ID? founder = _cachedGroupFounders[group];
    if (founder == null) {
      founder = await facebook?.getFounder(group);
      founder ??= ID.kFounder;  // placeholder
      _cachedGroupFounders[group] = founder;
    }
    return founder.isBroadcast ? null : founder;
  }

  @override
  Future<ID?> getOwner(ID group) async {
    ID? owner = _cachedGroupOwners[group];
    if (owner == null) {
      owner = await facebook?.getOwner(group);
      owner ??= ID.kAnyone;  // placeholder
      _cachedGroupOwners[group] = owner;
    }
    return owner.isBroadcast ? null : owner;
  }

  @override
  Future<List<ID>> getMembers(ID group) async {
    List<ID>? members = _cachedGroupMembers[group];
    if (members == null) {
      members = await facebook!.getMembers(group);
      _cachedGroupMembers[group] = members;
    }
    return members;
  }

  @override
  Future<List<ID>> getAssistants(ID group) async {
    List<ID>? bots = _cachedGroupAssistants[group];
    if (bots == null) {
      bots = await facebook!.getAssistants(group);
      _cachedGroupAssistants[group] = bots;
    }
    if (bots.isNotEmpty) {
      return bots;
    }
    // get from global setting
    if (_defaultAssistants.isEmpty) {
      // TODO: get from ANS
    }
    return _defaultAssistants;
  }

  //
  //  MemberShip
  //

  Future<bool> isFounder(ID member, ID group) async {
    ID? founder = await getFounder(group);
    if (founder != null) {
      return founder == member;
    }
    // check member's public key with group's meta.key
    Meta? gMeta = await getMeta(group);
    assert(gMeta != null, 'failed to get meta for group: $group');
    Meta? mMeta = await getMeta(member);
    assert(mMeta != null, 'failed to get meta for member: $member');
    return gMeta!.matchPublicKey(mMeta!.publicKey);
  }

  Future<bool> isOwner(ID member, ID group) async {
    ID? owner = await getOwner(group);
    if (owner != null) {
      return owner == member;
    }
    if (group.type == EntityType.kGroup ) {
      // this is a polylogue
      return await isFounder(member, group);
    }
    throw Exception('only Polylogue so far');
  }

  //
  //  members
  //

  Future<bool> containsMember(ID member, ID group) async {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = await getMembers(group);
    int pos = allMembers.indexOf(member);
    if (pos >= 0) {
      return true;
    }
    ID? owner = await getOwner(group);
    return owner != null && owner == member;
  }

  Future<bool> addMember(ID member, ID group) async {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = await getMembers(group);
    int pos = allMembers.indexOf(member);
    if (pos >= 0) {
      // already exists
      return false;
    }
    allMembers.add(member);
    return await saveMembers(allMembers, group);
  }
  Future<bool> removeMember(ID member, ID group) async {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = await getMembers(group);
    int pos = allMembers.indexOf(member);
    if (pos < 0) {
      // not exists
      return false;
    }
    allMembers.removeAt(pos);
    return await saveMembers(allMembers, group);
  }

  // private
  Future<List<ID>> addMembers(List<ID> newMembers, ID group) async {
    List<ID> members = await getMembers(group);
    int count = 0;
    for (ID member in newMembers) {
      if (members.contains(member)) {
        continue;
      }
      members.add(member);
      ++count;
    }
    if (count > 0) {
      await saveMembers(members, group);
    }
    return members;
  }
  // private
  Future<List<ID>> removeMembers(List<ID> outMembers, ID group) async {
    List<ID> members = await getMembers(group);
    int count = 0;
    for (ID member in outMembers) {
      if (!members.contains(member)) {
        continue;
      }
      members.remove(member);
      ++count;
    }
    if (count > 0) {
      await saveMembers(members, group);
    }
    return members;
  }

  Future<bool> saveMembers(List<ID> members, ID group) async {
    AccountDBI db = facebook!.database;
    if (await db.saveMembers(members, group: group)) {
      // erase cache for reload
      _cachedGroupMembers.remove(group);
      return true;
    } else {
      return false;
    }
  }

  //
  //  assistants
  //

  Future<bool> containsAssistant(ID user, ID group) async {
    List<ID> assistants = await getAssistants(group);
    if (assistants == _defaultAssistants) {
      // assistants not found
      return false;
    }
    return assistants.contains(user);
  }

  Future<bool> addAssistant(ID bot, ID? group) async {
    if (group == null) {
      assert(!_defaultAssistants.contains(bot), 'duplicated: $bot');
      _defaultAssistants.insert(0, bot);
      return true;
    }
    List<ID> assistants = await getAssistants(group);
    if (assistants == _defaultAssistants) {
      // assistants not found
      assistants = [];
    } else if (assistants.contains(bot)) {
      // already exists
      return false;
    }
    assistants.insert(0, bot);
    return await saveAssistants(assistants, group);
  }

  Future<bool> saveAssistants(List<ID> bots, ID group) async {
    AccountDBI db = facebook!.database;
    if (await db.saveAssistants(bots, group: group)) {
      // erase cache for reload
      _cachedGroupAssistants.remove(group);
      return true;
    } else {
      return false;
    }
  }

  Future<bool> removeGroup(ID group) async {
    // TODO: remove group completely
    //return groupTable.removeGroup(group);
    return false;
  }

}
