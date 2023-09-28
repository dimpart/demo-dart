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

class GroupCommandHelper extends TwinsHelper {
  GroupCommandHelper(super.facebook, super.messenger);

  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  Future<Document?> getDocument(ID group) async {
    Document? doc = await facebook?.getDocument(group, '*');
    if (doc == null) {
      messenger?.queryDocument(group);
    }
    return doc;
  }

  Future<ID?> getOwner(ID group) async {
    Document? doc = await getDocument(group);
    if (doc == null) {
      // the owner(founder) should be set in the bulletin document of group
      return null;
    }
    return await facebook?.getOwner(group);
  }

  Future<List<ID>> getAssistants(ID group) async {
    Document? doc = await getDocument(group);
    if (doc == null) {
      // the group assistants should be set in the bulletin document
      return [];
    }
    return await facebook!.getAssistants(group);
  }

  /// administrators
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

  /// members
  Future<List<ID>> getMembers(ID group) async {
    ID? owner = await getOwner(group);
    if (owner == null) {
      // the owner must exist before members
      return [];
    }
    return await facebook!.getMembers(group);
  }
  Future<bool> saveMembers(ID group, List<ID> members) async {
    AccountDBI? db = facebook?.database;
    return db!.saveMembers(members, group: group);
  }

  /// reset command message
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage(ID group) async {
    AccountDBI? db = facebook?.database;
    return await db!.getResetCommandMessage(group: group);
  }
  Future<bool> saveResetCommandMessage(ID group, ResetCommand content, ReliableMessage rMsg) async {
    assert(group == content.group, 'group ID error: $group, $content');
    AccountDBI? db = facebook?.database;
    return await db!.saveResetCommandMessage(content, rMsg, group: group);
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
      Document? bulletin = await getDocument(group);
      if (bulletin == null) {
        assert(false, 'group document not exists: $group');
        return true;
      }
      return AccountDBI.isExpired(bulletin.time, content.time);
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
  static List<ID> getMembersFromCommand(GroupCommand content) {
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
