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
  CommonFacebook(AccountDBI adb) : _database = adb;

  final AccountDBI _database;
  User? _current;

  AccountDBI get database => _database;

  @override
  List<User> get localUsers {
    List<User> users = [];
    User? usr;
    List<ID> array = database.getLocalUsers();
    if (array.isEmpty) {
      usr = _current;
      if (usr != null) {
        users.add(usr);
      }
    } else {
      for (ID item in array) {
        assert(getPrivateKeyForSignature(item) == null, 'error: $item');
        usr = getUser(item);
        assert(usr != null, 'failed to create user: $item');
        users.add(usr!);
      }
    }
    return users;
  }

  User? get currentUser {
    // Get current user (for signing and sending message)
    User? usr = _current;
    if (usr == null) {
      List<User> users = localUsers;
      if (users.isNotEmpty) {
        usr = users[0];
        _current = usr;
      }
    }
    return usr;
  }
  set currentUser(User? user) {
    _current = user;
  }

  @override
  bool saveMeta(Meta meta, ID identifier) => database.saveMeta(meta, identifier);

  @override
  bool saveDocument(Document doc) => database.saveDocument(doc);

  @override
  User? createUser(ID identifier) {
    if (!identifier.isBroadcast) {
      if (getPublicKeyForEncryption(identifier) == null) {
        // visa.key not found
        return null;
      }
    }
    return super.createUser(identifier);
  }

  @override
  Group? createGroup(ID identifier) {
    if (!identifier.isBroadcast) {
      if (getMeta(identifier) == null) {
        // group meta not found
        return null;
      }
    }
    return super.createGroup(identifier);
  }

  //
  //  EntityDataSource
  //

  @override
  Meta? getMeta(ID identifier) => database.getMeta(identifier);

  @override
  Document? getDocument(ID identifier, String? docType)
  => database.getDocument(identifier, docType);

  @override
  List<ID> getContacts(ID user) => database.getContacts(user);

  @override
  List<DecryptKey> getPrivateKeysForDecryption(ID user)
  => database.getPrivateKeysForDecryption(user);

  @override
  SignKey? getPrivateKeyForSignature(ID user)
  => database.getPrivateKeyForSignature(user);

  @override
  SignKey? getPrivateKeyForVisaSignature(ID user)
  => database.getPrivateKeyForVisaSignature(user);

  //
  //  GroupDataSource
  //

  @override
  ID? getFounder(ID group) {
    ID? user = database.getFounder(group);
    if (user != null) {
      // got from database
      return user;
    }
    return super.getFounder(group);
  }

  @override
  ID? getOwner(ID group) {
    ID? user = database.getOwner(group);
    if (user != null) {
      // got from database
      return user;
    }
    return super.getOwner(group);
  }

  @override
  List<ID> getMembers(ID group) {
    List<ID> users = database.getMembers(group);
    if (users.isNotEmpty) {
      // got from database
      return users;
    }
    return super.getMembers(group);
  }

  @override
  List<ID> getAssistants(ID group) {
    List<ID> bots = database.getAssistants(group);
    if (bots.isNotEmpty) {
      // got from database
      return bots;
    }
    return super.getAssistants(group);
  }

}
