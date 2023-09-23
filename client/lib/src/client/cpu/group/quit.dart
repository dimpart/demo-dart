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
import 'package:lnc/lnc.dart';
import 'package:object_key/object_key.dart';

import '../group.dart';

///  Quit Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. remove the sender from members of the group
///      2. owner and administrator cannot quit
class QuitCommandProcessor extends GroupCommandProcessor {
  QuitCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is QuitCommand, 'quit command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    if (await isCommandExpired(command)) {
      // ignore expired command
      return [];
    }
    ID group = command.group!;
    String text;

    // 1. check group
    ID? owner = await getOwner(group);
    List<ID> members = await getMembers(group);
    if (owner == null || members.isEmpty) {
      // TODO: query group members?
      text = 'Group empty.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Group empty: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    ID sender = rMsg.sender;
    List<ID> admins = await getAdministrators(group);
    bool isOwner = owner == sender;
    bool isAdmin = admins.contains(sender);
    bool isMember = members.contains(sender);

    // 2. check membership
    if (isOwner) {
      text = 'Permission denied.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Owner cannot quit from group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    if (isAdmin) {
      text = 'Permission denied.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Administrator cannot quit from group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. do quit
    members = [...members];
    if (isMember) {
      // member do exist, remove it and update database
      members.remove(sender);
      if (await saveMembers(members, group)) {
        command['removed'] = [sender.toString()];
      }
    }

    // 4. update 'reset' command
    User? user = await facebook?.currentUser;
    assert(user != null, 'failed to get current user');
    ID me = user!.identifier;
    if (owner == me || admins.contains(me)) {
      // this is the group owner (or administrator), so
      // it has permission to reset group members here.
      bool ok = await _refreshMembers(group: group, admin: me, members: members);
      assert(ok, 'failed to refresh members for group: $group');
    } else {
      // add 'quit' application for waiting admin to update
      bool ok = await addApplication(command, rMsg);
      assert(ok, 'failed to add "quit" application for group: $group');
    }
    if (!isMember) {
      text = 'Permission denied.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Not a member of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // no need to response this group command
    return [];
  }

  Future<bool> _refreshMembers({required ID group, required ID admin, required List<ID> members}) async {
    // 1. create new 'reset' command
    Pair<ResetCommand, ReliableMessage?> pair = await createResetCommand(sender: admin, group: group, members: members);
    ResetCommand cmd = pair.first;
    ReliableMessage? msg = pair.second;
    if (msg == null) {
      assert(false, 'failed to create "reset" command for group: $group');
      return false;
    } else if (await updateResetCommandMessage(group: group, content: cmd, rMsg: msg)) {
      Log.info('update "reset" command for group: $group');
    } else {
      assert(false, 'failed to save "reset" command message for group: $group');
      return false;
    }
    Content forward = ForwardContent.create(forward: msg);
    // 2. forward to assistants
    List<ID> bots = await getAssistants(group);
    for (ID receiver in bots) {
      if (admin == receiver) {
        assert(false, 'group bot should not be admin: $admin');
        continue;
      }
      messenger?.sendContent(forward, sender: admin, receiver: receiver, priority: 1);
    }
    return true;
  }

}
