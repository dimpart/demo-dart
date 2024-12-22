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
import 'package:lnc/log.dart';

import 'dbi/account.dart';

class CommonArchivist with Logging implements Archivist {
  CommonArchivist(Facebook facebook, AccountDBI db)
      : _barrack = WeakReference(facebook), database = db;

  final WeakReference<Facebook> _barrack;
  final AccountDBI database;

  // protected
  Facebook? get facebook => _barrack.target;

  @override
  Future<User?> createUser(ID identifier) async {
    assert(identifier.isUser, 'user ID error: $identifier');
    // check visa key
    if (!identifier.isBroadcast) {
      if (await facebook?.getPublicKeyForEncryption(identifier) == null) {
        assert(false, 'visa.key not found: $identifier');
        return null;
      }
      // NOTICE: if visa.key exists, then visa & meta must exist too.
    }
    int network = identifier.type;
    // check user type
    if (network == EntityType.STATION) {
      return Station.fromID(identifier);
    } else if (network == EntityType.BOT) {
      return Bot(identifier);
    }
    // general user, or 'anyone@anywhere'
    return BaseUser(identifier);
  }

  @override
  Future<Group?> createGroup(ID identifier) async {
    assert(identifier.isGroup, 'group ID error: $identifier');
    // check members
    if (!identifier.isBroadcast) {
      List<ID>? members = await facebook?.getMembers(identifier);
      if (members == null || members.isEmpty) {
        assert(false, 'group members not found: $identifier');
        return null;
      }
      // NOTICE: if members exist, then owner (founder) must exist,
      //         and bulletin & meta must exist too.
    }
    int network = identifier.type;
    // check group type
    if (network == EntityType.ISP) {
      return ServiceProvider(identifier);
    }
    // general group, or 'everyone@everywhere'
    return BaseGroup(identifier);
  }

  @override
  Future<VerifyKey?> getMetaKey(ID user) async {
    Meta? meta = await facebook?.getMeta(user);
    // assert(meta != null, 'failed to get meta for: $entity');
    return meta?.publicKey;
  }

  @override
  Future<EncryptKey?> getVisaKey(ID user) async {
    var docs = await facebook?.getDocuments(user);
    var visa = docs == null ? null : DocumentHelper.lastVisa(docs);
    // assert(doc != null, 'failed to get visa for: $user');
    return visa?.publicKey;
  }

  @override
  Future<List<User>> get localUsers async {
    var barrack = facebook;
    List<ID> array = await database.getLocalUsers();
    if (barrack == null || array.isEmpty) {
      assert(false, 'failed to get local users: $array');
      return [];
    }
    List<User> allUsers = [];
    User? user;
    for (ID item in array) {
      assert(await barrack.getPrivateKeyForSignature(item) != null, 'error: $item');
      user = await barrack.getUser(item);
      if (user != null) {
        allUsers.add(user);
      } else {
        assert(false, 'failed to create user: $item');
      }
    }
    return allUsers;
  }

}
