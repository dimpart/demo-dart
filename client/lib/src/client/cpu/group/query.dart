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

import '../../../common/protocol/groups.dart';
import '../group.dart';

///  Query Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. query for group members-list
///      2. any existed member or assistant can query group members-list
class QueryCommandProcessor extends GroupCommandProcessor {
  QueryCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is QueryCommand, 'query command error: $content');
    QueryCommand command = content as QueryCommand;

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
    List<ID> bots = await getAssistants(group);
    bool isMember = members.contains(sender);
    bool isBot = bots.contains(sender);

    // 2. check permission
    bool canQuery = isMember || isBot;
    if (!canQuery) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to query members of group: \${gid}',
        'replacements': {
          'gid': group.toString(),
        }
      });
    }

    // check last group time
    DateTime? queryTime = command.lastTime;
    if (queryTime != null) {
      // check last group history time
      var checker = facebook?.entityChecker;
      DateTime? lastTime = await checker?.getLastGroupHistoryTime(group);
      if (lastTime == null) {
        assert(false, 'group history error: $group');
      } else if (!lastTime.isAfter(queryTime)) {
        // group history not updated
        text = 'Group history not updated.';
        return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
          'template': 'Group history not updated: \${gid}, last time: \${time}',
          'replacements': {
            'gid': group.toString(),
            'time': lastTime.millisecondsSinceEpoch / 1000.0,
          }
        });
      }
    }

    // 3. send newest group history commands
    bool ok = await sendGroupHistories(group: group, receiver: sender);
    assert(ok, 'failed to send history for group: $group => $sender');

    // no need to response this group command
    return [];
  }

}
