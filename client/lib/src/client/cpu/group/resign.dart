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
import 'package:dimsdk/dimsdk.dart';

import '../group.dart';

///  Resign Group Admin Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. remove the sender from administrators of the group
///      2. administrator can be hired/fired by owner only
class ResignCommandProcessor extends GroupCommandProcessor {
  ResignCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is ResignCommand, 'resign command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    Pair<ID?, List<Content>?> pair = await checkCommandExpired(command, rMsg);
    ID? group = pair.first;
    if (group == null) {
      // ignore expired command
      return pair.second ?? [];
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

    // 2. check permission
    if (isOwner) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Owner cannot resign from group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. do resign
    if (!isAdmin) {
      // the sender is not an administrator now,
      // shall we notify the sender that the administrators list was updated?
    } else if (!await saveGroupHistory(group, command, rMsg)) {
      // here try to append the 'resign' command to local storage as group history
      // it should not failed unless the command is expired
      logError('failed to save "resign" command for group: $group');
    } else if (await saveAdministrators(group, [...admins]..remove(sender))) {
      // here try to remove the sender from admin list
      command['removed'] = [sender.toString()];
    } else {
      // DB error?
      assert(false, 'failed to save administrators for group: $group');
    }

    // no need to response this group command
    return [];
  }

}
