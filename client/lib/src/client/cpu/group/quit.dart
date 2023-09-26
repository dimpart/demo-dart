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
    Pair<ID?, List<Content>?> grpPair = await checkCommandExpired(command, rMsg);
    ID? group = grpPair.first;
    if (group == null) {
      // ignore expired command
      return grpPair.second ?? [];
    }

    // 1. check group
    Triplet<ID?, List<ID>, List<Content>?> trip = await checkGroupMembers(command, rMsg);
    ID? owner = trip.first;
    List<ID> members = trip.second;
    if (owner == null || members.isEmpty) {
      return trip.third ?? [];
    }
    String text;

    ID sender = rMsg.sender;
    List<ID> admins = await getAdministrators(group);
    bool isOwner = owner == sender;
    bool isAdmin = admins.contains(sender);
    bool isMember = members.contains(sender);

    // 2. check permissions
    if (isOwner) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Owner cannot quit from group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    if (isAdmin) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Administrator cannot quit from group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. do quit
    if (isMember) {
      // member do exist, remove it and update database
      members = [...members];
      members.remove(sender);
      if (await saveMembers(group, members)) {
        command['removed'] = [sender.toString()];
      } else {
        assert(false, 'failed to save members for group: $group');
      }
    }

    // 4. update 'reset' command
    User? user = await facebook?.currentUser;
    assert(user != null, 'failed to get current user');
    ID? me = user?.identifier;
    if (owner == me || admins.contains(me)) {
      // this is the group owner (or administrator), so
      // it has permission to reset group members here.
    } else if (await attachApplication(command, rMsg)) {
      // add 'quit' application for querying by other members,
      // if the owner/admin wakeup, they will broadcast a new 'reset' command
      // with the newest members, and this local 'reset' command will be erased.
    } else {
      assert(false, 'failed to add "quit" application for group: $group');
    }

    // no need to response this group command
    return [];
  }

}
