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

import '../common/dbi/account.dart';
import '../common/facebook.dart';
import '../common/messenger.dart';

class GroupDelegate extends TwinsHelper implements GroupDataSource {
  GroupDelegate(super.facebook, super.messenger);

  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  AccountDBI? get database => facebook?.database;

  Future<String> buildGroupName(List<ID> members) async {
    assert(members.isNotEmpty, 'members should not be empty here');
    CommonFacebook barrack = facebook!;
    String text = await barrack.getName(members.first);
    String nickname;
    for (int i = 1; i < members.length; ++i) {
      nickname = await barrack.getName(members[i]);
      if (nickname.isEmpty) {
        continue;
      }
      text += ', $nickname';
      if (text.length > 32) {
        return '${text.substring(0, 28)} ...';
      }
    }
    return text;
  }

  //
  //  Entity DataSource
  //

  @override
  Future<Meta?> getMeta(ID identifier) async {
    Meta? meta = await facebook?.getMeta(identifier);
    if (meta == null) {
      // if not found, query it from any station
      messenger?.queryMeta(identifier);
    }
    return meta;
  }

  @override
  Future<Document?> getDocument(ID identifier, String? docType) async {
    Document? doc = await facebook?.getDocument(identifier, docType);
    if (doc == null) {
      // if not found, query it from any station
      messenger?.queryDocument(identifier);
    }
    return doc;
  }

  Future<bool> saveDocument(Document doc) async =>
      await facebook!.saveDocument(doc);

  //
  //  Group DataSource
  //

  @override
  Future<ID?> getFounder(ID group) async {
    assert(group.isGroup, 'ID error: $group');
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      // the owner(founder) should be set in the bulletin document of group
      return null;
    }
    return await facebook?.getFounder(group);
  }

  @override
  Future<ID?> getOwner(ID group) async {
    assert(group.isGroup, 'ID error: $group');
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      // the owner(founder) should be set in the bulletin document of group
      return null;
    }
    return await facebook?.getOwner(group);
  }

  @override
  Future<List<ID>> getAssistants(ID group) async {
    assert(group.isGroup, 'ID error: $group');
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      // the group assistants should be set in the bulletin document
      return [];
    }
    return await facebook!.getAssistants(group);
  }

  @override
  Future<List<ID>> getMembers(ID group) async {
    assert(group.isGroup, 'ID error: $group');
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      // group not ready
      return [];
    }
    List<ID> members = await facebook!.getMembers(group);
    if (members.length < 2) {
      // members not found, query the owner (or group bots)
      messenger?.queryMembers(group);
    }
    return members;
  }

  Future<bool> saveMembers(ID group, List<ID> members) async =>
      await database!.saveMembers(members, group: group);

  //
  //  Administrators
  //

  Future<List<ID>> getAdministrators(ID group) async {
    assert(group.isGroup, 'ID error: $group');
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      // group not ready
      return [];
    }
    List<ID> admins = await database!.getAdministrators(group: group);
    if (admins.isNotEmpty) {
      // got from database
      return admins;
    }
    var array = doc.getProperty('administrators');
    if (array is List) {
      // got from bulletin document
      return ID.convert(array);
    }
    // administrators not found
    return [];
  }

  Future<bool> saveAdministrators(ID group, List<ID> admins) async =>
      await database!.saveAdministrators(admins, group: group);

  //
  //  Membership
  //

  Future<bool> isFounder(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    ID? founder = await getFounder(group);
    if (founder != null) {
      return founder == user;
    }
    // check member's public key with group's meta.key
    Meta? gMeta = await getMeta(group);
    Meta? mMeta = await getMeta(user);
    if (gMeta == null || mMeta == null) {
      assert(false, 'failed to get meta for group: $group, user: $user');
      return false;
    }
    return gMeta.matchPublicKey(mMeta.publicKey);
  }

  Future<bool> isOwner(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    ID? owner = await getOwner(group);
    if (owner != null) {
      return owner == user;
    }
    if (group.type == EntityType.kGroup) {
      // this is a polylogue
      return await isFounder(user, group: group);
    }
    throw Exception('only Polylogue so far');
  }

  Future<bool> isMember(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    List<ID> members = await getMembers(group);
    return members.contains(user);
  }

  Future<bool> isAdministrator(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    List<ID> admins = await getAdministrators(group);
    return admins.contains(user);
  }

  Future<bool> isAssistant(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    List<ID> bots = await getAssistants(group);
    return bots.contains(user);
  }

}
