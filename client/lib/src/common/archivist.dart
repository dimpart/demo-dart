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

import 'dbi/account.dart';

abstract class CommonArchivist extends Archivist implements UserDataSource, GroupDataSource {

  final AccountDBI database;

  CommonArchivist(this.database) : super(Archivist.kQueryExpires);

  @override
  Future<DateTime?> getLastGroupHistoryTime(ID group) async {
    var array = await database.getGroupHistories(group: group);
    if (array.isEmpty) {
      return null;
    }
    DateTime? lastTime;
    DateTime? hisTime;
    for (var pair in array) {
      hisTime = pair.first.time;
      if (hisTime == null) {
        assert(false, 'group command error: ${pair.first}');
      } else if (lastTime == null || lastTime.isBefore(hisTime)) {
        lastTime = hisTime;
      }
    }
    return lastTime;
  }

  Future<List<ID>> getLocalUsers() async =>
      await database.getLocalUsers();

  @override
  Future<bool> saveMeta(Meta meta, ID identifier) async =>
      await database.saveMeta(meta, identifier);

  @override
  Future<bool> saveDocument(Document doc) async {
    DateTime? docTime = doc.time;
    if (docTime == null) {
      assert(false, 'document error: $doc');
    } else {
      // calibrate the clock
      // make sure the document time is not in the far future
      int current = DateTime.now().millisecondsSinceEpoch + 65536;
      if (docTime.millisecondsSinceEpoch > current) {
        assert(false, 'document time error: $docTime, $doc');
        return false;
      }
    }
    return await database.saveDocument(doc);
  }

  //
  //  EntityDataSource
  //

  @override
  Future<Meta?> getMeta(ID identifier) async =>
      await database.getMeta(identifier);

  @override
  Future<List<Document>> getDocuments(ID identifier) async =>
      await database.getDocuments(identifier);

  //
  //  UserDataSource
  //

  @override
  Future<List<ID>> getContacts(ID user) async =>
      await database.getContacts(user: user);

  @override
  Future<EncryptKey?> getPublicKeyForEncryption(ID user) async {
    assert(false, 'DON\'t call me!');
    return null;
  }

  @override
  Future<List<VerifyKey>> getPublicKeysForVerification(ID user) async {
    assert(false, 'DON\'t call me!');
    return [];
  }

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async =>
      await database.getPrivateKeysForDecryption(user);

  @override
  Future<SignKey?> getPrivateKeyForSignature(ID user) async =>
      await database.getPrivateKeyForSignature(user);

  @override
  Future<SignKey?> getPrivateKeyForVisaSignature(ID user) async =>
      await database.getPrivateKeyForVisaSignature(user);

  //
  //  GroupDataSource
  //

  @override
  Future<ID?> getFounder(ID group) async =>
      await database.getFounder(group: group);

  @override
  Future<ID?> getOwner(ID group) async =>
      await database.getOwner(group: group);

  @override
  Future<List<ID>> getMembers(ID group) async =>
      await database.getMembers(group: group);

  @override
  Future<List<ID>> getAssistants(ID group) async =>
      await database.getAssistants(group: group);

  //
  //  Organization Structure
  //

  Future<List<ID>> getAdministrators({required ID group}) async =>
      await database.getAdministrators(group: group);

  Future<bool> saveAdministrators(List<ID> members, {required ID group}) async =>
      await database.saveAdministrators(members, group: group);

  Future<bool> saveMembers(List<ID> members, {required ID group}) async =>
      await database.saveMembers(members, group: group);

}
