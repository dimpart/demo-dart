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
import 'package:object_key/object_key.dart';

import '../../common/facebook.dart';
import '../../common/messenger.dart';
import 'group_helper.dart';


class HistoryCommandProcessor extends BaseCommandProcessor {
  HistoryCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is HistoryCommand, 'history command error: $content');
    HistoryCommand command = content as HistoryCommand;
    String text = 'Command not support.';
    return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'History command (name: \${command}) not support yet!',
      'replacements': {
        'command': command.cmd,
      },
    });
  }

}


class GroupCommandProcessor extends HistoryCommandProcessor {
  GroupCommandProcessor(super.facebook, super.messenger);

  GroupCommandHelper? _handler;

  GroupCommandHelper get helper {
    GroupCommandHelper? helper = _handler;
    if (helper == null) {
      _handler = helper = createGroupCommandHelper();
    }
    return helper;
  }
  /// override for customized helper
  GroupCommandHelper createGroupCommandHelper() =>
      GroupCommandHelper(facebook!, messenger!);

  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  // protected
  Future<ID?> getOwner(ID group) async =>
      await helper.getOwner(group);

  // protected
  Future<List<ID>> getAssistants(ID group) async =>
      await helper.getAssistants(group);

  // protected
  Future<List<ID>> getAdministrators(ID group) async =>
      await helper.getAdministrators(group);
  // protected
  Future<bool> saveAdministrators(ID group, List<ID> admins) async =>
      await helper.saveAdministrators(group, admins);

  // protected
  Future<List<ID>> getMembers(ID group) async =>
      await helper.getMembers(group);
  // protected
  Future<bool> saveMembers(ID group, List<ID> members) async =>
      await helper.saveMembers(group, members);

  // protected
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage(ID group) async =>
      await helper.getResetCommandMessage(group);
  // protected
  Future<bool> saveResetCommandMessage(ID group, ResetCommand content, ReliableMessage rMsg) async =>
      await helper.saveResetCommandMessage(group, content, rMsg);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is GroupCommand, 'group command error: $content');
    GroupCommand command = content as GroupCommand;
    String text = 'Command not support.';
    return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'Group command (name: \${command}) not support yet!',
      'replacements': {
        'command': command.cmd,
      },
    });
  }

  // protected
  Future<Pair<ID?, List<Content>?>> checkCommandExpired(GroupCommand content, ReliableMessage rMsg) async {
    bool expired = await helper.isCommandExpired(content);
    if (expired) {
      String text = 'Command expired.';
      return Pair(null, respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Group command expired: \${ID}',
        'replacements': {
          'ID': content.group?.toString(),
        }
      }));
    }
    // group ID must not empty here
    return Pair(content.group, null);
  }

  // protected
  Future<Pair<List<ID>, List<Content>?>> checkCommandMembers(GroupCommand content, ReliableMessage rMsg) async {
    List<ID> members = GroupCommandHelper.getMembersFromCommand(content);
    if (members.isNotEmpty) {
      // group is ready
      return Pair(members, null);
    }
    String text = 'Command error.';
    return Pair(members, respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'Group members empty: \${ID}',
      'replacements': {
        'ID': content.group?.toString(),
      }
    }));
  }

  // protected
  Future<Triplet<ID?, List<ID>, List<Content>?>> checkGroupMembers(GroupCommand content, ReliableMessage rMsg) async {
    ID? group = content.group;
    if (group == null) {
      assert(false, 'group command error: $content');
      return Triplet(null, [], null);
    }
    ID? owner = await getOwner(group);
    List<ID> members = await getMembers(group);
    if (owner != null && members.isNotEmpty) {
      // group is ready
      return Triplet(owner, members, null);
    }
    // TODO: query group members?
    String text = 'Group empty.';
    return Triplet(owner, members, respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'Group empty: \${ID}',
      'replacements': {
        'ID': group.toString(),
      }
    }));
  }

  /// attach 'invite', 'join', 'quit', 'resign' commands to 'reset' command message
  /// for owner/admins to review
  Future<bool> attachApplication(GroupCommand content, ReliableMessage rMsg) async {
    assert(content is InviteCommand
        || content is JoinCommand
        || content is QuitCommand
        || content is ResignCommand, 'group command error: $content');
    // TODO: attach 'resign' command to document?
    ID? group = content.group;
    if (group == null) {
      assert(false, 'group command error: $content');
      return false;
    }
    Pair<ResetCommand?, ReliableMessage?> pair = await getResetCommandMessage(group);
    ResetCommand? cmd = pair.first;
    ReliableMessage? msg = pair.second;
    if (cmd == null || msg == null) {
      assert(false, 'failed to get "reset" command message for group: $group');
      return false;
    }
    var applications = msg['applications'];
    List array;
    if (applications is List) {
      array = applications;
    } else {
      array = [];
      msg['applications'] = array;
    }
    array.add(rMsg.toMap());
    return await saveResetCommandMessage(group, cmd, msg);
  }

  /// send a reset command with newest members to the receiver
  Future<bool> sendResetCommand({required ID group, required List<ID> members, required ID receiver}) async {
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    Pair<ResetCommand?, ReliableMessage?> pair = await getResetCommandMessage(group);
    ReliableMessage? msg = pair.second;
    if (msg == null) {
      // 'reset' command message not found in local storage
      // check permission for creating a new one
      ID? owner = await getOwner(group);
      if (me != owner) {
        // not group owner, check administrators
        List<ID> admins = await getAdministrators(group);
        if (!admins.contains(me)) {
          // only group owner or administrators can reset group members
          return false;
        }
      }
      // assert(me.type != EntityType.kBot, 'a bot should not be admin: $me');
      // this is the group owner (or administrator), so
      // it has permission to reset group members here.
      pair = await createResetCommand(group: group, members: members);
      msg = pair.second;
      if (msg == null) {
        assert(false, 'failed to create "reset" command for group: $group');
        return false;
      }
      // because the owner/administrator can create 'reset' command,
      // so no need to save it here.
    }
    // OK, forward the 'reset' command message
    Content content = ForwardContent.create(forward: msg);
    await messenger?.sendContent(content, sender: me, receiver: receiver, priority: 1);
    return true;
  }

  /// create 'reset' group message for anyone
  Future<Pair<ResetCommand?, ReliableMessage?>> createResetCommand({required ID group, required List<ID> members}) async {
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return Pair(null, null);
    }
    ID me = user.identifier;
    // create broadcast 'reset' group message
    Envelope head = Envelope.create(sender: me, receiver: ID.kAnyone);
    ResetCommand body = GroupCommand.reset(group, members: members);
    InstantMessage iMsg = InstantMessage.create(head, body);
    // encrypt & sign
    SecureMessage? sMsg;
    ReliableMessage? rMsg;
    sMsg = await messenger?.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message: $me => $group');
    } else {
      rMsg = await messenger?.signMessage(sMsg);
      assert(rMsg != null, 'failed to sign message: $me => $group');
    }
    return Pair(body, rMsg);
  }

}
