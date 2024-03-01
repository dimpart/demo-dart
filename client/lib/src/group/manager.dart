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
import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/log.dart';

import '../common/dbi/account.dart';
import '../common/register.dart';
import '../common/facebook.dart';
import '../common/messenger.dart';

import 'delegate.dart';
import 'helper.dart';
import 'builder.dart';
import 'packer.dart';

class GroupManager with Logging {
  GroupManager(this.delegate);

  // protected
  final GroupDelegate delegate;

  // protected
  late final GroupPacker packer = createPacker();

  // protected
  late final GroupCommandHelper helper = createHelper();
  // protected
  late final GroupHistoryBuilder builder = createBuilder();

  /// override for customized packer
  GroupPacker createPacker() => GroupPacker(delegate);

  /// override for customized helper
  GroupCommandHelper createHelper() => GroupCommandHelper(delegate);
  /// override for customized builder
  GroupHistoryBuilder createBuilder() => GroupHistoryBuilder(delegate);

  // protected
  CommonFacebook? get facebook => delegate.facebook;
  // protected
  CommonMessenger? get messenger => delegate.messenger;

  // protected
  AccountDBI? get database => facebook?.archivist.database;

  ///  Create new group with members
  ///  (broadcast document & members to all members and neighbor station)
  ///
  /// @param members - initial group members
  /// @return new group ID
  Future<ID?> createGroup(List<ID> members) async {
    assert(members.length > 1, 'not enough members: $members');

    //
    //  0. get current user
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return null;
    }
    ID founder = user.identifier;

    //
    //  1. check founder (owner)
    //
    int pos = members.indexOf(founder);
    if (pos < 0) {
      // put me in the first position
      members.insert(0, founder);
    } else if (pos > 0) {
      // move me to the front
      members.removeAt(pos);
      members.insert(0, founder);
    }
    String groupName = await delegate.buildGroupName(members);

    //
    //  2. create group with name
    //
    Register register = Register(database!);
    ID group = await register.createGroup(founder, name: groupName);
    logInfo('new group: $group ($groupName), founder: $founder');

    //
    //  3. upload meta+document to neighbor station(s)
    //  DISCUSS: should we let the neighbor stations know the group info?
    //
    Meta? meta = await delegate.getMeta(group);
    Bulletin? doc = await delegate.getBulletin(group);
    Command content;
    if (doc != null) {
      content = DocumentCommand.response(group, meta, doc);
    } else if (meta != null) {
      content = MetaCommand.response(group, meta);
    } else {
      assert(false, 'failed to get group info: $group');
      return null;
    }
    bool ok = await _sendCommand(content, receiver: Station.kAny);  // to neighbor(s)
    assert(ok, 'failed to upload meta/document to neighbor station');

    //
    //  4. create & broadcast 'reset' group command with new members
    //
    if (await resetMembers(group, members)) {
      logInfo('created group $group with ${members.length} members');
    } else {
      logError('failed to create group $group with ${members.length} members');
    }

    return group;
  }

  // DISCUSS: should we let the neighbor stations know the group info?
  //      (A) if we do this, it can provide a convenience that,
  //          when someone receive a message from an unknown group,
  //          it can query the group info from the neighbor immediately;
  //          and its potential risk is that anyone not in the group can also
  //          know the group info (only the group ID, name, and admins, ...)
  //      (B) but, if we don't let the station knows it,
  //          then we must shared the group info with our members themselves;
  //          and if none of them is online, you cannot get the newest info
  //          immediately until someone online again.

  ///  Reset group members
  ///  (broadcast new group history to all members)
  ///
  /// @param group      - group ID
  /// @param newMembers - new member list
  /// @return false on error
  Future<bool> resetMembers(ID group, List<ID> newMembers) async {
    assert(group.isGroup && newMembers.isNotEmpty, 'params error: $group, $newMembers');

    //
    //  0. get current user
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    // check member list
    ID first = newMembers.first;
    bool ok = await delegate.isOwner(first, group: group);
    if (!ok) {
      assert(false, 'group owner must be the first member: $group');
      return false;
    }
    // member list OK, check expelled members
    List<ID> oldMembers = await delegate.getMembers(group);
    List<ID> expelList = [];
    for (ID item in oldMembers) {
      if (!newMembers.contains(item)) {
        expelList.add(item);
      }
    }

    //
    //  1. check permission
    //
    bool isOwner = me == first;
    bool isAdmin = await delegate.isAdministrator(me, group: group);
    bool isBot = await delegate.isAssistant(me, group: group);
    bool canReset = isOwner || isAdmin;
    if (!canReset) {
      assert(false, 'cannot reset members of group: $group');
      return false;
    }
    // only the owner or admin can reset group members
    assert(!isBot, 'group bot cannot reset members: $group, $me');

    //
    //  2. build 'reset' command
    //
    var pair = await builder.buildResetCommand(group, newMembers);
    ResetCommand? reset = pair.first;
    ReliableMessage? rMsg = pair.second;
    if (reset == null || rMsg == null) {
      assert(false, 'failed to build "reset" command for group: $group');
      return false;
    }

    //
    //  3. save 'reset' command, and update new members
    //
    if (!await helper.saveGroupHistory(group, reset, rMsg)) {
      assert(false, 'failed to save "reset" command for group: $group');
      return false;
    } else if (!await delegate.saveMembers(group, newMembers)) {
      assert(false, 'failed to update members of group: $group');
      return false;
    } else {
      logInfo('group members updated: $group, ${newMembers.length}');
    }

    //
    //  4. forward all group history
    //
    List<ReliableMessage> messages = await builder.buildGroupHistories(group);
    ForwardContent forward = ForwardContent.create(secrets: messages);

    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // let the group bots know the newest member ID list,
      // so they can split group message correctly for us.
      return _sendCommand(forward, members: bots);      // to all assistants
    } else {
      // group bots not exist,
      // send the command to all members
      _sendCommand(forward, members: newMembers);       // to new members
      _sendCommand(forward, members: expelList);        // to removed members
    }

    return true;
  }

  ///  Invite new members to this group
  ///
  /// @param group      - group ID
  /// @param newMembers - inviting member list
  /// @return false on error
  Future<bool> inviteMembers(ID group, List<ID> newMembers) async {
    assert(group.isGroup && newMembers.isNotEmpty, 'params error: $group, $newMembers');

    //
    //  0. get current user
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    List<ID> oldMembers = await delegate.getMembers(group);

    bool isOwner = await delegate.isOwner(me, group: group);
    bool isAdmin = await delegate.isAdministrator(me, group: group);
    bool isMember = await delegate.isMember(me, group: group);

    //
    //  1. check permission
    //
    bool canReset = isOwner || isAdmin;
    if (canReset) {
      // You are the owner/admin, then
      // append new members and 'reset' the group
      List<ID> members = [...oldMembers];
      for (ID item in newMembers) {
        if (!members.contains(item)) {
          members.add(item);
        }
      }
      return resetMembers(group, members);
    } else if (!isMember) {
      assert(false, 'cannot invite member into group: $group');
      return false;
    }
    // invited by ordinary member

    //
    //  2. build 'invite' command
    //
    InviteCommand invite = GroupCommand.invite(group, members: newMembers);
    ReliableMessage? rMsg = await packer.packMessage(invite, sender: me);
    if (rMsg == null) {
      assert(false, 'failed to build "invite" command for group: $group');
      return false;
    } else if (!await helper.saveGroupHistory(group, invite, rMsg)) {
      assert(false, 'failed to save "invite" command for group: $group');
      return false;
    }
    ForwardContent forward = ForwardContent.create(forward: rMsg);

    //
    //  3. forward group command(s)
    //
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // let the group bots know the newest member ID list,
      // so they can split group message correctly for us.
      return _sendCommand(forward, members: bots);      // to all assistants
    }

    // forward 'invite' to old members
    _sendCommand(forward, members: oldMembers);         // to old members

    // forward all group history to new members
    List<ReliableMessage> messages = await builder.buildGroupHistories(group);
    forward = ForwardContent.create(secrets: messages);

    // TODO: remove that members already exist before sending?
    _sendCommand(forward, members: newMembers);         // to new members
    return true;
  }

  ///  Quit from this group
  ///  (broadcast a 'quit' command to all members)
  ///
  /// @param group - group ID
  /// @return false on error
  Future<bool> quitGroup(ID group) async {
    assert(group.isGroup, 'group ID error: $group');

    //
    //  0. get current user
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    List<ID> members = await delegate.getMembers(group);
    assert(members.isNotEmpty, 'failed to get members for group: $group');

    bool isOwner = await delegate.isOwner(me, group: group);
    bool isAdmin = await delegate.isAdministrator(me, group: group);
    bool isBot = await delegate.isAssistant(me, group: group);
    bool isMember = members.contains(me);

    //
    //  1. check permission
    //
    if (isOwner) {
      assert(false, 'owner cannot quit from group: $group');
      return false;
    } else if (isAdmin) {
      assert(false, 'administrator cannot quit from group: $group');
      return false;
    }
    assert(!isBot, 'group bot cannot quit: $group, $me');

    //
    //  2. update local storage
    //
    if (isMember) {
      logWarning('quitting group: $group, $me');
      members = [...members];
      members.remove(me);
      bool ok = await delegate.saveMembers(group, members);
      assert(ok, 'failed to save members for group: $group');
    } else {
      logWarning('member not in group: $group, $me');
    }

    //
    //  3. build 'quit' command
    //
    Command content = GroupCommand.quit(group);
    ReliableMessage? rMsg = await packer.packMessage(content, sender: me);
    if (rMsg == null) {
      assert(false, 'failed to pack group message: $group');
      return false;
    }
    ForwardContent forward = ForwardContent.create(forward: rMsg);

    //
    //  4. forward 'quit' command
    //
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // let the group bots know the newest member ID list,
      // so they can split group message correctly for us.
      return _sendCommand(forward, members: bots);      // to group bots
    } else {
      // group bots not exist,
      // send the command to all members directly
      return _sendCommand(forward, members: members);   // to all members
    }
  }

  Future<bool> _sendCommand(Content content, {ID? receiver, List<ID>? members}) async {
    if (receiver != null) {
      assert(members == null, 'params error: $receiver, $members');
      members = [receiver];
    } else if (members == null) {
      assert(false, 'params error');
      return false;
    }
    // 1. get sender
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'should not happen: $user');
      return false;
    }
    ID me = user.identifier;
    // 2. send to all receivers
    CommonMessenger? transceiver = messenger;
    for (ID receiver in members) {
      if (me == receiver) {
        logInfo('skip cycled message: $me => $receiver');
        continue;
      }
      transceiver?.sendContent(content, sender: me, receiver: receiver, priority: 1);
    }
    return true;
  }

}
