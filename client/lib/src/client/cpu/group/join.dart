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

import '../group.dart';

///  Join Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. stranger can join a group
///      2. only group owner or administrator can review this command
class JoinCommandProcessor extends GroupCommandProcessor {
  JoinCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is JoinCommand, 'join command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    if (await isCommandExpired(command)) {
      // ignore expired command
      return [];
    }
    ID group = command.group!;

    // 1. check group
    ID? owner = await getOwner(group);
    List<ID> members = await getMembers(group);
    if (owner == null || members.isEmpty) {
      // TODO: query group members?
      return respondReceipt('Group empty.', rMsg, group: group, extra: {
        'template': 'Group empty: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 2. check membership
    ID sender = rMsg.sender;
    if (members.contains(sender)) {
      // maybe the sender is already a member,
      // but if it can still receive a 'join' command here,
      // we should respond the sender with the newest membership again.
      bool ok = await sendResetCommand(group: group, members: members, receiver: sender);
      assert(ok, 'failed to send "reset" command for group: $group => $sender');
    } else {
      // add 'join' application for waiting review
      bool ok = await addApplication(command, rMsg);
      assert(ok, 'failed to add "join" application for group: $group');
    }

    // no need to response this group command
    return [];
  }

}
