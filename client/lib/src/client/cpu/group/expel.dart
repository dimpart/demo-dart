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
import 'package:object_key/object_key.dart';

import '../group.dart';

///  Expel Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. remove group member(s)
///      2. only group owner or administrator can expel member
class ExpelCommandProcessor extends GroupCommandProcessor {
  ExpelCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is ExpelCommand, 'expel command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    if (await isCommandExpired(command)) {
      // ignore expired command
      return [];
    }
    ID group = command.group!;
    String text;
    List<ID> expelList = getMembersFromCommand(command);
    if (expelList.isEmpty) {
      text = 'Command error.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Expel list is empty: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

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

    // 2. check permission
    if (!isOwner && !isAdmin) {
      text = 'Permission denied.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to expel member from group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    // 2.1. check owner
    if (expelList.contains(owner)) {
      text = 'Permission denied.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to expel owner of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    // 2.2. check admins
    bool expelAdmin = false;
    for (ID item in admins) {
      if (expelList.contains(item)) {
        expelAdmin = true;
        break;
      }
    }
    if (expelAdmin) {
      text = 'Permission denied.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to expel administrator of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. do expel
    Pair<List<ID>, List<ID>> pair = _calculateExpelled(members: members, expelList: expelList);
    List<ID> newMembers = pair.first;
    List<ID> removeList = pair.second;
    if (removeList.isEmpty && !isOwner) {
      // maybe those users are already expelled,
      // but if it can still receive an 'expel' command here,
      // we should respond the sender with the newest membership again.
      bool ok = await sendResetCommand(group: group, members: newMembers, receiver: sender);
      assert(ok, 'failed to send "reset" command for group: $group => $sender');
    } else if (await saveMembers(newMembers, group)) {
      command['removed'] = ID.revert(removeList);
    }

    // no need to response this group command
    return [];
  }

  Pair<List<ID>, List<ID>> _calculateExpelled({required List<ID> members, required List<ID> expelList}) {
    List<ID> newMembers = [];
    List<ID> removeList = [];
    for (ID item in members) {
      if (expelList.contains(item)) {
        removeList.add(item);
      } else {
        newMembers.add(item);
      }
    }
    return Pair(newMembers, removeList);
  }

}
