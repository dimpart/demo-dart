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

import 'archivist.dart';
import 'anonymous.dart';


///  Common Facebook with Database
abstract class CommonFacebook extends Facebook {
  CommonFacebook() : _current = null;

  User? _current;

  @override
  CommonArchivist get archivist;

  @override
  Future<List<User>> get localUsers async {
    List<User> users = [];
    User? usr;
    List<ID> array = await archivist.getLocalUsers();
    if (array.isEmpty) {
      usr = _current;
      if (usr != null) {
        users.add(usr);
      }
    } else {
      for (ID item in array) {
        assert(await getPrivateKeyForSignature(item) != null, 'error: $item');
        usr = await getUser(item);
        if (usr != null) {
          users.add(usr);
        } else {
          assert(false, 'failed to create user: $item');
        }
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
        usr = users.first;
        _current = usr;
      }
    }
    return usr;
  }
  setCurrentUser(User user) {
    user.dataSource ??= this;
    _current = user;
  }

  Future<Document?> getDocument(ID identifier, [String? type]) async {
    List<Document> documents = await getDocuments(identifier);
    Document? doc = DocumentHelper.lastDocument(documents, type);
    // compatible for document type
    if (doc == null && type == Document.kVisa) {
      doc = DocumentHelper.lastDocument(documents, 'profile');
    }
    return doc;
  }

  Future<String> getName(ID identifier) async {
    String type;
    if (identifier.isUser) {
      type = Document.kVisa;
    } else if (identifier.isGroup) {
      type = Document.kBulletin;
    } else {
      type = '*';
    }
    // get name from document
    Document? doc = await getDocument(identifier, type);
    if (doc != null) {
      String? name = doc.name;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    // get name from ID
    return Anonymous.getName(identifier);
  }

  //
  //  UserDataSource
  //

  @override
  Future<List<ID>> getContacts(ID user) async =>
      await archivist.getContacts(user);

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async =>
      await archivist.getPrivateKeysForDecryption(user);

  @override
  Future<SignKey?> getPrivateKeyForSignature(ID user) async =>
      await archivist.getPrivateKeyForSignature(user);

  @override
  Future<SignKey?> getPrivateKeyForVisaSignature(ID user) async =>
      await archivist.getPrivateKeyForVisaSignature(user);

}
