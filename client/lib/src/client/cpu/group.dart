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

import '../../common/dbi/account.dart';
import '../../common/facebook.dart';
import '../../common/messenger.dart';


class HistoryCommandProcessor extends BaseCommandProcessor {
  HistoryCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is HistoryCommand, 'history command error: $content');
    HistoryCommand command = content as HistoryCommand;
    String text = 'Command not support.';
    return respondReceipt(text, rMsg, group: content.group, extra: {
      'template': 'History command (name: \${command}) not support yet!',
      'replacements': {
        'command': command.cmd,
      },
    });
  }

}


class GroupCommandProcessor extends HistoryCommandProcessor {
  GroupCommandProcessor(super.facebook, super.messenger);

  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  // protected
  Future<ID?> getOwner(ID group) async {
    return await facebook?.getOwner(group);
  }
  // protected
  Future<List<ID>> getMembers(ID group) async {
    return await facebook!.getMembers(group);
  }
  // protected
  Future<List<ID>> getAssistants(ID group) async {
    return await facebook!.getAssistants(group);
  }
  // protected
  Future<List<ID>> getAdministrators(ID group) async {
    AccountDBI? db = facebook?.database;
    return await db!.getAdministrators(group: group);
  }

  // protected
  Future<bool> saveMembers(List<ID> members, ID group) async {
    AccountDBI? db = facebook?.database;
    return db!.saveMembers(members, group: group);
  }
  // protected
  Future<bool> saveAdministrators(List<ID> members, ID group) async {
    AccountDBI? db = facebook?.database;
    return db!.saveAdministrators(members, group: group);
  }

  // protected
  List<ID> getMembersFromCommand(GroupCommand content) {
    // get from 'members'
    List<ID>? members = content.members;
    if (members == null) {
      members = [];
      // get from 'member'
      ID? member = content.member;
      if (member != null) {
        members.add(member);
      }
    }
    return members;
  }

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is GroupCommand, 'group command error: $content');
    GroupCommand command = content as GroupCommand;
    String text = 'Command not support.';
    return respondReceipt(text, rMsg, group: content.group, extra: {
      'template': 'Group command (name: \${command}) not support yet!',
      'replacements': {
        'command': command.cmd,
      },
    });
  }

  // protected
  Future<bool> isCommandExpired(GroupCommand content) async {
    ID? group = content.group;
    if (group == null) {
      assert(false, 'group content error: $content');
      return true;
    }
    if (content is ResignCommand) {
      // administrator command, check with document time
      Document? bulletin = await facebook?.getDocument(group, '*');
      if (bulletin == null) {
        return false;
      }
      return AccountDBI.isExpired(bulletin.time, content.time);
    }
    // membership command, check with reset command
    AccountDBI? db = facebook?.database;
    Pair<ResetCommand?, ReliableMessage?>? pair = await db?.getResetCommandMessage(group);
    if (pair == null || pair.first == null/* || pair.second == null*/) {
      return false;
    }
    return AccountDBI.isExpired(pair.first?.time, content.time);
  }

  /// attach 'invite', 'join', 'quit' commands to 'reset' command message for owner/admins to review
  Future<bool> addApplication(GroupCommand content, ReliableMessage rMsg) async {
    assert(content is InviteCommand
        || content is JoinCommand
        || content is QuitCommand
        || content is ResignCommand, 'group command error: $content');
    // TODO: attach 'resign' command to document?
    AccountDBI? db = facebook?.database;
    ID group = content.group!;
    Pair<ResetCommand?, ReliableMessage?>? pair = await db?.getResetCommandMessage(group);
    if (pair == null || pair.first == null || pair.second == null) {
      User? user = await facebook?.currentUser;
      assert(user != null, 'failed to get current user');
      ID? me = user?.identifier;
      // TODO: check whether current user is the owner or an administrator
      //       if True, create a new 'reset' command with current members
      assert(me!.type == EntityType.kBot, 'failed to get reset command for group: $group');
      return false;
    }
    ResetCommand? cmd = pair.first;
    ReliableMessage? msg = pair.second;
    var applications = msg?['applications'];
    List array;
    if (applications is List) {
      array = applications;
    } else {
      array = [];
      msg?['applications'] = array;
    }
    array.add(rMsg.toMap());
    return await db!.saveResetCommandMessage(group, cmd!, msg!);
  }

  /// send a reset command with newest members to the receiver
  Future<bool> sendResetCommand({required ID group, required List<ID> members, required ID receiver}) async {
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    AccountDBI? db = facebook?.database;
    Pair<ResetCommand?, ReliableMessage?>? pair = await db?.getResetCommandMessage(group);
    if (pair == null || pair.second == null) {
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
      assert(me.type != EntityType.kBot, 'a bot should not be admin: $me');
      // this is the group owner (or administrator), so
      // it has permission to reset group members here.
      pair = await createResetCommand(sender: me, group: group, members: members);
      if (pair.second == null) {
        assert(false, 'failed to create "reset" command for group: $group');
        return false;
      }
      bool ok = await db!.saveResetCommandMessage(group, pair.first!, pair.second!);
      if (!ok) {
        assert(false, 'failed to save "reset" command message');
        return false;
      }
    }
    // OK, forward the 'reset' command message
    Content content = ForwardContent.create(forward: pair.second);
    await messenger?.sendContent(content, sender: me, receiver: receiver, priority: 1);
    return true;
  }

  /// create 'reset' command message for anyone in the group
  Future<Pair<ResetCommand, ReliableMessage?>> createResetCommand(
      {required ID sender, required ID group, required List<ID> members}) async {
    Envelope head = Envelope.create(sender: sender, receiver: ID.kAnyone);
    ResetCommand body = GroupCommand.reset(group, members: members);
    InstantMessage iMsg = InstantMessage.create(head, body);
    // encrypt & sign
    SecureMessage? sMsg;
    ReliableMessage? rMsg;
    sMsg = await messenger?.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message: $sender => $group');
    } else {
      rMsg = await messenger?.signMessage(sMsg);
      if (rMsg == null) {
        assert(false, 'failed to sign message: $sender => $group');
      }
    }
    return Pair(body, rMsg);
  }

  /// save 'reset' command message with 'applications
  Future<bool> updateResetCommandMessage({required ID group, required ResetCommand content, required ReliableMessage rMsg}) async {
    AccountDBI? db = facebook?.database;
    List? applications;
    // 1. get applications
    Pair<ResetCommand?, ReliableMessage?>? pair = await db?.getResetCommandMessage(group);
    if (pair != null && pair.second != null) {
      applications = pair.second!['applications'];
    }
    if (applications == null) {
      applications = rMsg['applications'];
    } else {
      List? invitations = rMsg['applications'];
      if (invitations != null) {
        applications = Copier.copyList(applications);
        // merge applications
        applications.addAll(invitations);
      }
    }
    // 2. update applications
    if (applications != null) {
      rMsg['applications'] = applications;
    }
    // 3. save reset command message
    return await db!.saveResetCommandMessage(group, content, rMsg);
  }

}
