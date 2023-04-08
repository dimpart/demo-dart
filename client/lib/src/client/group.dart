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
import 'package:dimp/dimp.dart';

import '../dim_network.dart';
import 'messenger.dart';

///  This is for sending group message, or managing group members
class GroupManager implements GroupDataSource {
  factory GroupManager() => _instance;
  static final GroupManager _instance = GroupManager._internal();
  GroupManager._internal();

  final Map<ID, ID>         _cachedGroupFounders = {};
  final Map<ID, ID>           _cachedGroupOwners = {};
  final Map<ID, List<ID>>    _cachedGroupMembers = {};
  final Map<ID, List<ID>> _cachedGroupAssistants = {};
  final List<ID>              _defaultAssistants = [];

  ClientMessenger? messenger;

  // private
  CommonFacebook? get facebook => messenger?.facebook;

  // private
  User? get currentUser => facebook?.currentUser;

  ///  Send group message content
  ///
  /// @param content - message content
  /// @return false on no bots found
  bool sendContent(Content content, ID group) {
    assert(group.isGroup, 'group ID error: $group');
    ID? gid = content.group;
    if (gid == null) {
      content.group = group;
    } else if (gid != group) {
      throw Exception('group ID not match: $gid, $group');
    }
    List<ID> assistants = getAssistants(group);
    Pair<InstantMessage, ReliableMessage?> result;
    for (ID bot in assistants) {
      // send to any bot
      result = messenger!.sendContent(content, sender: null, receiver: bot);
      if (result.second != null) {
        // only send to one bot, let the bot to split and
        // forward this message to all members
        return true;
      }
    }
    return false;
  }

  // private
  void sendCommand(Command content, {ID? receiver, List<ID>? members}) {
    if (receiver != null) {
      messenger!.sendContent(content, sender: null, receiver: receiver);
    }
    if (members != null) {
      ID? sender = currentUser?.identifier;
      for (ID item in members) {
        messenger!.sendContent(content, sender: sender, receiver: item);
      }
    }
  }


  ///  Invite new members to this group
  ///  (only existed member/assistant can do this)
  ///
  /// @param newMembers - new members ID list
  /// @return true on success
  bool invite(ID group, {ID? member, List<ID>? members}) {
    assert(group.isGroup, 'group ID error: $group');
    List<ID> newMembers = members ?? [member!];

    // TODO: make sure group meta exists
    // TODO: make sure current user is a member

    // 0. build 'meta/document' command
    Meta? meta = getMeta(group);
    if (meta == null) {
      throw Exception('failed to get meta for group: $group');
    }
    Document? doc = getDocument(group, "*");
    Command command;
    if (doc == null) {
      // empty document
      command = MetaCommand.response(group, meta);
    } else {
      command = DocumentCommand.response(group, meta, doc);
    }
    List<ID> bots = getAssistants(group);
    // 1. send 'meta/document' command
    sendCommand(command, members: bots);                // to all assistants

    // 2. update local members and notice all bots & members
    members = getMembers(group);
    if (members.length <= 2) { // new group?
      // 2.0. update local storage
      members = addMembers(newMembers, group);
      // 2.1. send 'meta/document' command
      sendCommand(command, members: members);         // to all members
      // 2.3. send 'invite' command with all members
      command = GroupCommand.invite(group, members: members);
      sendCommand(command, members: bots);            // to group assistants
      sendCommand(command, members: members);         // to all members
    } else {
      // 2.1. send 'meta/document' command
      //sendGroupCommand(command, members: members);  // to old members
      sendCommand(command, members: newMembers);      // to new members
      // 2.2. send 'invite' command with new members only
      command = GroupCommand.invite(group, members: newMembers);
      sendCommand(command, members: bots);            // to group assistants
      sendCommand(command, members: members);         // to old members
      // 3. update local storage
      members = addMembers(newMembers, group);
      // 2.4. send 'invite' command with all members
      command = GroupCommand.invite(group, members: members);
      sendCommand(command, members: newMembers);      // to new members
    }

    return true;
  }

  ///  Expel members from this group
  ///  (only group owner/assistant can do this)
  ///
  /// @param outMembers - existed member ID list
  /// @return true on success
  bool expel(ID group, {ID? member, List<ID>? members}) {
    assert(group.isGroup, 'group ID error: $group');
    List<ID> outMembers = members ?? [member!];
    ID? owner = getOwner(group);
    List<ID> bots = getAssistants(group);

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
    members = removeMembers(outMembers, group);

    // 2. send 'expel' command
    Command command = GroupCommand.expel(group, members: outMembers);
    sendCommand(command, members: bots);        // to assistants
    sendCommand(command, members: members);     // to new members
    sendCommand(command, members: outMembers);  // to expelled members

    return true;
  }

  ///  Quit from this group
  ///  (only group member can do this)
  ///
  /// @return true on success
  bool quit(ID group) {
    assert(group.isGroup, 'group ID error: $group');

    User? user = currentUser;
    if (user == null) {
      throw Exception('failed to get current user');
    }
    ID me = user.identifier;

    ID? owner = getOwner(group);
    List<ID> bots = getAssistants(group);
    List<ID> members = getMembers(group);

    // 0. check permission
    if (bots.contains(me)) {
      throw Exception('group assistant cannot quit: $me, group: $group');
    } else if (me == owner) {
      throw Exception('group owner cannot quit: $owner, group: $group');
    }

    // 1. update local storage
    bool ok = false;
    if (members.remove(me)) {
      ok = saveMembers(members, group);
      //} else {
      //    // not a member now
      //    return false;
    }

    // 2. send 'quit' command
    Command command = GroupCommand.quit(group);
    sendCommand(command, members: bots);     // to assistants
    sendCommand(command, members: members);  // to new members

    return ok;
  }

  ///  Query group info
  ///
  /// @return false on error
  bool query(ID group) {
    return messenger!.queryMembers(group);
  }

  //-------- Data Source

  @override
  Meta? getMeta(ID identifier) => facebook?.getMeta(identifier);

  @override
  Document? getDocument(ID identifier, String? docType)
  => facebook?.getDocument(identifier, docType);

  @override
  ID? getFounder(ID group) {
    ID? founder = _cachedGroupFounders[group];
    if (founder == null) {
      founder = facebook?.getFounder(group);
      founder ??= ID.kFounder;  // placeholder
      _cachedGroupFounders[group] = founder;
    }
    return founder.isBroadcast ? null : founder;
  }

  @override
  ID? getOwner(ID group) {
    ID? owner = _cachedGroupOwners[group];
    if (owner == null) {
      owner = facebook?.getOwner(group);
      owner ??= ID.kAnyone;  // placeholder
      _cachedGroupOwners[group] = owner;
    }
    return owner.isBroadcast ? null : owner;
  }

  @override
  List<ID> getMembers(ID group) {
    List<ID>? members = _cachedGroupMembers[group];
    if (members == null) {
      members = facebook!.getMembers(group);
      _cachedGroupMembers[group] = members;
    }
    return members;
  }

  @override
  List<ID> getAssistants(ID group) {
    List<ID>? bots = _cachedGroupAssistants[group];
    if (bots == null) {
      bots = facebook!.getAssistants(group);
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

  bool isFounder(ID member, ID group) {
    ID? founder = getFounder(group);
    if (founder != null) {
      return founder == member;
    }
    // check member's public key with group's meta.key
    Meta? gMeta = getMeta(group);
    assert(gMeta != null, 'failed to get meta for group: $group');
    Meta? mMeta = getMeta(member);
    assert(mMeta != null, 'failed to get meta for member: $member');
    return Meta.matchKey(mMeta!.key, gMeta!);
  }

  bool isOwner(ID member, ID group) {
    ID? owner = getOwner(group);
    if (owner != null) {
      return owner == member;
    }
    if (group.type == EntityType.kGroup ) {
      // this is a polylogue
      return isFounder(member, group);
    }
    throw Exception('only Polylogue so far');
  }

  //
  //  members
  //

  bool containsMember(ID member, ID group) {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = getMembers(group);
    int pos = allMembers.indexOf(member);
    if (pos >= 0) {
      return true;
    }
    ID? owner = getOwner(group);
    return owner != null && owner == member;
  }

  bool addMember(ID member, ID group) {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = getMembers(group);
    int pos = allMembers.indexOf(member);
    if (pos >= 0) {
      // already exists
      return false;
    }
    allMembers.add(member);
    return saveMembers(allMembers, group);
  }
  bool removeMember(ID member, ID group) {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = getMembers(group);
    int pos = allMembers.indexOf(member);
    if (pos < 0) {
      // not exists
      return false;
    }
    allMembers.removeAt(pos);
    return saveMembers(allMembers, group);
  }

  // private
  List<ID> addMembers(List<ID> newMembers, ID group) {
    List<ID> members = getMembers(group);
    int count = 0;
    for (ID member in newMembers) {
      if (members.contains(member)) {
        continue;
      }
      members.add(member);
      ++count;
    }
    if (count > 0) {
      saveMembers(members, group);
    }
    return members;
  }
  // private
  List<ID> removeMembers(List<ID> outMembers, ID group) {
    List<ID> members = getMembers(group);
    int count = 0;
    for (ID member in outMembers) {
      if (!members.contains(member)) {
        continue;
      }
      members.remove(member);
      ++count;
    }
    if (count > 0) {
      saveMembers(members, group);
    }
    return members;
  }

  bool saveMembers(List<ID> members, ID group) {
    AccountDBI db = facebook!.database;
    if (db.saveMembers(members, group)) {
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

  bool containsAssistant(ID user, ID group) {
    List<ID> assistants = getAssistants(group);
    if (assistants == _defaultAssistants) {
      // assistants not found
      return false;
    }
    return assistants.contains(user);
  }

  bool addAssistant(ID bot, ID? group) {
    if (group == null) {
      _defaultAssistants.insert(0, bot);
      return true;
    }
    List<ID> assistants = getAssistants(group);
    if (assistants == _defaultAssistants) {
      // assistants not found
      assistants = [];
    } else if (assistants.contains(bot)) {
      // already exists
      return false;
    }
    assistants.insert(0, bot);
    return saveAssistants(assistants, group);
  }

  bool saveAssistants(List<ID> bots, ID group) {
    AccountDBI db = facebook!.database;
    if (db.saveAssistants(bots, group)) {
      // erase cache for reload
      _cachedGroupAssistants.remove(group);
      return true;
    } else {
      return false;
    }
  }

  bool removeGroup(ID group) {
    // TODO: remove group completely
    //return groupTable.removeGroup(group);
    return false;
  }

}
