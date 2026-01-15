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
import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/log.dart';

import 'dbi/account.dart';
import 'mkm/utils.dart';

import 'archivist.dart';
import 'anonymous.dart';
import 'checker.dart';


///  Common Facebook with Database
abstract class CommonFacebook extends Facebook with Logging {
  CommonFacebook(this.database);

  final AccountDBI database;

  CommonArchivist? _barrack;
  EntityChecker? entityChecker;

  User? _currentUser;

  @override
  Archivist? get archivist => _barrack;

  @override
  CommonArchivist? get barrack => _barrack;
  set barrack(CommonArchivist? archivist) => _barrack = archivist;

  //
  //  Current User
  //

  Future<User?> get currentUser async {
    // Get current user (for signing and sending message)
    User? current = _currentUser;
    if (current != null) {
      return current;
    }
    List<ID> array = await database.getLocalUsers();
    if (array.isEmpty) {
      return null;
    }
    assert(await getPrivateKeyForSignature(array.first) != null, 'user error: ${array.first}');
    current = await getUser(array.first);
    _currentUser = current;
    return current;
  }
  Future<void> setCurrentUser(User user) async {
    user.dataSource ??= this;
    _currentUser = user;
  }

  @override
  Future<ID?> selectLocalUser(ID receiver) async {
    User? user = _currentUser;
    if (user != null) {
      ID current = user.identifier;
      if (receiver.isBroadcast) {
        // broadcast message can be decrypted by anyone, so
        // just return current user here
        return current;
      } else if (receiver.isGroup) {
        // group message (recipient not designated)
        //
        // the messenger will check group info before decrypting message,
        // so we can trust that the group's meta & members MUST exist here.
        List<ID> members = await getMembers(receiver);
        if (members.isEmpty) {
          assert(false, 'members not found: $receiver');
          return null;
        } else if (members.contains(current)) {
          return current;
        }
      } else if (receiver == current) {
        return current;
      }
    }
    // check local users
    return await super.selectLocalUser(receiver);
  }

  //
  //  Documents
  //

  Future<Document?> getDocument(ID identifier, [String? type]) async {
    List<Document> documents = await getDocuments(identifier);
    Document? doc = DocumentUtils.lastDocument(documents, type);
    // compatible for document type
    if (doc == null && type == DocumentType.VISA) {
      doc = DocumentUtils.lastDocument(documents, DocumentType.PROFILE);
    }
    return doc;
  }

  Future<Visa?> getVisa(ID user) async {
    List<Document> documents = await getDocuments(user);
    return DocumentUtils.lastVisa(documents);
  }

  Future<Bulletin?> getBulletin(ID group) async {
    List<Document> documents = await getDocuments(group);
    return DocumentUtils.lastBulletin(documents);
  }

  Future<String> getName(ID identifier) async {
    String type;
    if (identifier.isUser) {
      type = DocumentType.VISA;
    } else if (identifier.isGroup) {
      type = DocumentType.BULLETIN;
    } else {
      type = '*';
    }
    // get name from document
    Document? doc = await getDocument(identifier, type);
    if (doc != null) {
      String? name = doc.getProperty('name');
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    // get name from ID
    return Anonymous.getName(identifier);
  }

  Future<PortableNetworkFile?> getAvatar(ID user) async {
    Visa? doc = await getVisa(user);
    return doc?.avatar;
  }

  //
  //  Entity DataSource
  //

  @override
  Future<Meta?> getMeta(ID identifier) async {
    Meta? meta = await database.getMeta(identifier);
    /*await */entityChecker?.checkMeta(identifier, meta);
    return meta;
  }

  @override
  Future<List<Document>> getDocuments(ID identifier) async {
    List<Document> docs = await database.getDocuments(identifier);
    /*await */entityChecker?.checkDocuments(identifier, docs);
    return docs;
  }

  //
  //  User DataSource
  //

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
  //  Organizational Structure
  //

  Future<List<ID>> getAdministrators(ID group);
  Future<bool> saveAdministrators(List<ID> admins, ID group);

  Future<List<ID>> getAssistants(ID group);

  Future<bool> saveMembers(List<ID> newMembers, ID group);

}
