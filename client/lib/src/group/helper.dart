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
import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';

import '../common/dbi/account.dart';

import 'delegate.dart';

class GroupCommandHelper with Logging {
  GroupCommandHelper(this.delegate);

  // protected
  final GroupDelegate delegate;

  // protected
  AccountDBI? get database => delegate.facebook?.archivist.database;

  ///
  /// Group History Command
  ///
  Future<bool> saveGroupHistory(ID group, GroupCommand content, ReliableMessage rMsg) async {
    assert(group == content.group, 'group ID error: $group, $content');
    if (await isCommandExpired(content)) {
      warning('drop expired command: ${content.cmd}, ${rMsg.sender} => $group');
      return false;
    }
    // check command time
    DateTime? cmdTime = content.time;
    if (cmdTime == null) {
      assert(false, 'group command error: $content');
    } else {
      // calibrate the clock
      // make sure the command time is not in the far future
      int current = DateTime.now().millisecondsSinceEpoch + 65536;
      if (cmdTime.millisecondsSinceEpoch > current) {
        assert(false, 'group command time error: $cmdTime, $content');
        return false;
      }
    }
    // update group history
    AccountDBI? db = database;
    if (content is ResetCommand) {
      warning('cleaning group history for "reset" command: ${rMsg.sender} => $group');
      await db!.clearGroupMemberHistories(group: group);
    }
    return await db!.saveGroupHistory(content, rMsg, group: group);
  }
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories(ID group) async {
    AccountDBI? db = database;
    return await db!.getGroupHistories(group: group);
  }
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage(ID group) async {
    AccountDBI? db = database;
    return await db!.getResetCommandMessage(group: group);
  }
  Future<bool> clearGroupMemberHistories(ID group) async {
    AccountDBI? db = database;
    return await db!.clearGroupMemberHistories(group: group);
  }
  Future<bool> clearGroupAdminHistories(ID group) async {
    AccountDBI? db = database;
    return await db!.clearGroupAdminHistories(group: group);
  }

  /// check command time
  /// (all group commands received must after the cached 'reset' command)
  Future<bool> isCommandExpired(GroupCommand content) async {
    ID? group = content.group;
    if (group == null) {
      assert(false, 'group content error: $content');
      return true;
    }
    if (content is ResignCommand) {
      // administrator command, check with document time
      Bulletin? doc = await delegate.getBulletin(group);
      if (doc == null) {
        assert(false, 'group document not exists: $group');
        return true;
      }
      return DocumentHelper.isBefore(doc.time, content.time);
    }
    // membership command, check with reset command
    Pair<ResetCommand?, ReliableMessage?> pair = await getResetCommandMessage(group);
    ResetCommand? cmd = pair.first;
    // ReliableMessage? msg = pair.second;
    if (cmd == null/* || msg == null*/) {
      return false;
    }
    return DocumentHelper.isBefore(cmd.time, content.time);
  }

  /// members
  Future<List<ID>> getMembersFromCommand(GroupCommand content) async {
    // get from 'members'
    List<ID>? members = content.members;
    if (members == null) {
      members = [];
      // get from 'member'
      ID? single = content.member;
      if (single != null) {
        members.add(single);
      }
    }
    return members;
  }

}
