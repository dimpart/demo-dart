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
import 'package:lnc/lnc.dart';
import 'package:object_key/object_key.dart';

import '../../common/dbi/account.dart';
import '../../common/facebook.dart';
import '../../common/messenger.dart';

class GroupCommandHelper extends TwinsHelper {
  GroupCommandHelper(super.facebook, super.messenger);

  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  /// get group meta
  /// if not found, query it from any station
  Future<Meta?> getMeta(ID group) async {
    Meta? meta = await facebook?.getMeta(group);
    if (meta == null) {
      messenger?.queryMeta(group);
    }
    return meta;
  }

  /// get group document
  /// if not found, query it from any station
  Future<Document?> getDocument(ID group) async {
    Document? doc = await facebook?.getDocument(group, '*');
    if (doc == null) {
      messenger?.queryDocument(group);
    }
    return doc;
  }

  /// get group owner
  /// when bulletin document exists
  Future<ID?> getOwner(ID group) async {
    Document? doc = await getDocument(group);
    if (doc == null) {
      // the owner(founder) should be set in the bulletin document of group
      return null;
    }
    return await facebook?.getOwner(group);
  }

  /// get group bots
  /// when bulletin document exists
  Future<List<ID>> getAssistants(ID group) async {
    Document? doc = await getDocument(group);
    if (doc == null) {
      // the group assistants should be set in the bulletin document
      return [];
    }
    return await facebook!.getAssistants(group);
  }

  /// get administrators
  /// when bulletin document exists
  Future<List<ID>> getAdministrators(ID group) async {
    Document? doc = await getDocument(group);
    if (doc == null) {
      // the administrators should be set in the bulletin document
      return [];
    }
    AccountDBI? db = facebook?.database;
    return await db!.getAdministrators(group: group);
  }
  Future<bool> saveAdministrators(ID group, List<ID> admins) async {
    AccountDBI? db = facebook?.database;
    return db!.saveAdministrators(admins, group: group);
  }

  /// get members when owner exists,
  /// if not found, query from bots/admins/owner
  Future<List<ID>> getMembers(ID group) async {
    ID? owner = await getOwner(group);
    if (owner == null) {
      // the owner must exist before members
      return [];
    }
    List<ID> members = await facebook!.getMembers(group);
    if (members.isEmpty) {
      messenger?.queryMembers(group);
    }
    return members;
  }
  Future<bool> saveMembers(ID group, List<ID> members) async {
    AccountDBI? db = facebook?.database;
    return db!.saveMembers(members, group: group);
  }

  ///
  /// Group History Command
  ///
  Future<bool> saveGroupHistory(ID group, GroupCommand content, ReliableMessage rMsg) async {
    assert(group == content.group, 'group ID error: $group, $content');
    if (await isCommandExpired(content)) {
      Log.warning('drop expired command: ${content.cmd}, ${rMsg.sender} => $group');
      return false;
    }
    AccountDBI? db = facebook?.database;
    if (content is ResetCommand) {
      Log.warning('cleaning group history for "reset" command: ${rMsg.sender} => $group');
      await db!.clearGroupMemberHistories(group: group);
    }
    return await db!.saveGroupHistory(content, rMsg, group: group);
  }
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories(ID group) async {
    AccountDBI? db = facebook?.database;
    return await db!.getGroupHistories(group: group);
  }
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage(ID group) async {
    AccountDBI? db = facebook?.database;
    return await db!.getResetCommandMessage(group: group);
  }
  Future<bool> clearGroupMemberHistories(ID group) async {
    AccountDBI? db = facebook?.database;
    return await db!.clearGroupMemberHistories(group: group);
  }
  Future<bool> clearGroupAdminHistories(ID group) async {
    AccountDBI? db = facebook?.database;
    return await db!.clearGroupAdminHistories(group: group);
  }

  /// command time
  /// (all group commands received must after the cached 'reset' command)
  Future<bool> isCommandExpired(GroupCommand content) async {
    ID? group = content.group;
    if (group == null) {
      assert(false, 'group content error: $content');
      return true;
    }
    if (content is ResignCommand) {
      // administrator command, check with document time
      Document? doc = await getDocument(group);
      if (doc == null) {
        assert(false, 'group document not exists: $group');
        return true;
      }
      return AccountDBI.isExpired(doc.time, content.time);
    }
    // membership command, check with reset command
    Pair<ResetCommand?, ReliableMessage?> pair = await getResetCommandMessage(group);
    ResetCommand? cmd = pair.first;
    // ReliableMessage? msg = pair.second;
    if (cmd == null/* || msg == null*/) {
      return false;
    }
    return AccountDBI.isExpired(cmd.time, content.time);
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
