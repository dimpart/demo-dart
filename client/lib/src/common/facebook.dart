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

///  Common Facebook with Database
class CommonFacebook extends Facebook {
  CommonFacebook(AccountDBI adb) : _database = adb, _current = null;

  final AccountDBI _database;
  User? _current;

  AccountDBI get database => _database;

  @override
  Future<List<User>> get localUsers async {
    List<User> users = [];
    User? usr;
    List<ID> array = await database.getLocalUsers();
    if (array.isEmpty) {
      usr = _current;
      if (usr != null) {
        users.add(usr);
      }
    } else {
      for (ID item in array) {
        assert(await getPrivateKeyForSignature(item) != null, 'error: $item');
        usr = getUser(item);
        assert(usr != null, 'failed to create user: $item');
        users.add(usr!);
      }
    }
    return users;
  }

  Future<User?> get currentUser async {
    // Get current user (for signing and sending message)
    User? usr = _current;
    if (usr == null) {
      List<User> users = await localUsers;
      if (users.isNotEmpty) {
        usr = users[0];
        _current = usr;
      }
    }
    return usr;
  }
  setCurrentUser(User? user) {
    _current = user;
  }

  @override
  Future<bool> saveMeta(Meta meta, ID identifier) async =>
      await database.saveMeta(meta, identifier);

  @override
  Future<bool> saveDocument(Document doc) async =>
      await database.saveDocument(doc);

  // @override
  // User? createUser(ID identifier) {
  //   if (!identifier.isBroadcast) {
  //     if (getPublicKeyForEncryption(identifier) == null) {
  //       // visa.key not found
  //       return null;
  //     }
  //   }
  //   return super.createUser(identifier);
  // }
  //
  // @override
  // Group? createGroup(ID identifier) {
  //   if (!identifier.isBroadcast) {
  //     if (getMeta(identifier) == null) {
  //       // group meta not found
  //       return null;
  //     }
  //   }
  //   return super.createGroup(identifier);
  // }

  //
  //  EntityDataSource
  //

  @override
  Future<Meta?> getMeta(ID identifier) async =>
      await database.getMeta(identifier);

  @override
  Future<Document?> getDocument(ID identifier, String? docType) async =>
      await database.getDocument(identifier, docType);

  @override
  Future<List<ID>> getContacts(ID user) async =>
      await database.getContacts(user: user);

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
  Future<ID?> getFounder(ID group) async {
    ID? user = await database.getFounder(group: group);
    if (user != null) {
      // got from database
      return user;
    }
    return await super.getFounder(group);
  }

  @override
  Future<ID?> getOwner(ID group) async {
    ID? user = await database.getOwner(group: group);
    if (user != null) {
      // got from database
      return user;
    }
    return await super.getOwner(group);
  }

  @override
  Future<List<ID>> getMembers(ID group) async {
    List<ID> users = await database.getMembers(group: group);
    if (users.isNotEmpty) {
      // got from database
      return users;
    }
    return await super.getMembers(group);
  }

  @override
  Future<List<ID>> getAssistants(ID group) async {
    List<ID> bots = await database.getAssistants(group: group);
    if (bots.isNotEmpty) {
      // got from database
      return bots;
    }
    return await super.getAssistants(group);
  }

}
