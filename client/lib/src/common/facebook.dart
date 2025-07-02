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

import 'archivist.dart';
import 'anonymous.dart';
import 'checker.dart';


///  Common Facebook with Database
abstract class CommonFacebook extends Facebook with Logging {
  CommonFacebook(this.database);

  final AccountDBI database;

  CommonArchivist? _archivist;
  EntityChecker? checker;

  User? _currentUser;

  @override
  CommonArchivist get barrack => _archivist!;
  set barrack(CommonArchivist archivist) => _archivist = archivist;

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
  Future<List<User>> getLocalUsers() async {
    User? current = _currentUser;
    //
    //  1. get local user ID list
    //
    List<ID> array = await database.getLocalUsers();
    if (array.isEmpty) {
      return current == null ? [] : [current];
    }
    List<User> allUsers = [];
    //
    //  2. get all users
    //
    User? user;
    for (ID item in array) {
      assert(await getPrivateKeyForSignature(item) != null, 'user error: $item');
      user = await getUser(item);
      if (user != null) {
        allUsers.add(user);
      } else {
        assert(false, 'failed to create user: $item');
      }
    }
    //
    //  3. check current user
    //
    if (current != null && allUsers.isNotEmpty) {
      if (allUsers.first != current) {
        allUsers.insert(0, current);
      }
    }
    return allUsers;
  }

  @override
  Future<User?> selectLocalUser(ID receiver) async {
    List<User> allUsers = await getLocalUsers();
    //
    //  1.
    //
    if (allUsers.isEmpty) {
      assert(false, 'local users should not be empty');
      return null;
    } else if (receiver.isBroadcast) {
      // broadcast message can decrypt by anyone,
      // so just return current user
      return allUsers.first;
    }
    //
    //  2.
    //
    if (receiver.isUser) {
      for (User item in allUsers) {
        if (item.identifier == receiver) {
          // DISCUSS: set this item to be current user?
          return item;
        }
      }
    } else if (receiver.isGroup) {
      // group message (recipient not designated)
      //
      // the messenger will check group info before decrypting message,
      // so we can trust that the group's meta & members MUST exist here.
      List<ID> members = await getMembers(receiver);
      assert(members.isNotEmpty, 'members not found: $receiver');
      for (User item in allUsers) {
        if (members.contains(item.identifier)) {
          // DISCUSS: set this item to be current user?
          return item;
        }
      }
    } else {
      assert(false, 'receiver error: $receiver');
    }
    // not me?
    return null;
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
      String? name = doc.name;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    // get name from ID
    return Anonymous.getName(identifier);
  }

  // -------- Storage

  @override
  Future<bool> saveMeta(Meta meta, ID identifier) async {
    //
    //  1. check valid
    //
    if (!checkMeta(meta, identifier)) {
      assert(false, 'meta not valid: $identifier');
      return false;
    }
    //
    //  2. check duplicated
    //
    Meta? old = await getMeta(identifier);
    if (old != null) {
      logDebug('meta duplicated: $identifier');
      return true;
    }
    //
    //  3. save into database
    //
    return await database.saveMeta(meta, identifier);
  }

  // protected
  bool checkMeta(Meta meta, ID identifier) {
    return meta.isValid && MetaUtils.matchIdentifier(identifier, meta);
  }

  @override
  Future<bool> saveDocument(Document doc) async {
    //
    //  1. check valid
    //
    if (await checkDocumentValid(doc)) {
      // document valid
    } else {
      assert(false, 'meta not valid: ${doc.identifier}');
      return false;
    }
    //
    //  2. check expired
    //
    if (await checkDocumentExpired(doc)) {
      logInfo('drop expired document: $doc');
      return false;
    }
    //
    //  3. save into database
    //
    return await database.saveDocument(doc);
  }

  // protected
  Future<bool> checkDocumentValid(Document doc) async {
    ID identifier = doc.identifier;
    DateTime? docTime = doc.time;
    // check document time
    if (docTime == null) {
      // assert(false, 'document error: $doc');
      logWarning('document without time: $identifier');
    } else {
      // calibrate the clock
      // make sure the document time is not in the far future
      DateTime nearFuture = DateTime.now().add(Duration(minutes: 30));
      if (docTime.isAfter(nearFuture)) {
        assert(false, 'document time error: $docTime, $doc');
        logError('document time error: $docTime, $identifier');
        return false;
      }
    }
    // check valid
    return await verifyDocument(doc);
  }

  // protected
  Future<bool> verifyDocument(Document doc) async {
    if (doc.isValid) {
      return true;
    }
    Meta? meta = await getMeta(doc.identifier);
    if (meta == null) {
      logWarning('failed to get meta: ${doc.identifier}');
      return false;
    }
    return doc.verify(meta.publicKey);
  }

  // protected
  Future<bool> checkDocumentExpired(Document doc) async {
    ID identifier = doc.identifier;
    String type = DocumentUtils.getDocumentType(doc) ?? '*';
    // check old documents with type
    List<Document> documents = await getDocuments(identifier);
    Document? old = DocumentUtils.lastDocument(documents, type);
    return old != null && DocumentUtils.isExpired(doc, old);
  }

  @override
  Future<VerifyKey?> getMetaKey(ID user) async {
    Meta? meta = await getMeta(user);
    // assert(meta != null, 'failed to get meta for: $entity');
    return meta?.publicKey;
  }

  @override
  Future<EncryptKey?> getVisaKey(ID user) async {
    var docs = await getDocuments(user);
    var visa = DocumentUtils.lastVisa(docs);
    // assert(doc != null, 'failed to get visa for: $user');
    return visa?.publicKey;
  }

  //
  //  Entity DataSource
  //

  @override
  Future<Meta?> getMeta(ID identifier) async {
    var meta = await database.getMeta(identifier);
    /*await */checker?.checkMeta(identifier, meta);
    return meta;
  }

  @override
  Future<List<Document>> getDocuments(ID identifier) async {
    var docs = await database.getDocuments(identifier);
    /*await */checker?.checkDocuments(identifier, docs);
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

  Future<bool> saveMembers(List<ID> newMembers, ID group);

}
