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
import 'utils/cache.dart';

class CommonArchivist extends Barrack with Logging implements Archivist {
  CommonArchivist(Facebook facebook, this.database) : _facebook = WeakReference(facebook);

  final WeakReference<Facebook> _facebook;
  final AccountDBI database;

  // protected
  Facebook? get facebook => _facebook.target;

  /// memory caches
  late final MemoryCache<ID, User>   _userCache = createUserCache();
  late final MemoryCache<ID, Group> _groupCache = createGroupCache();

  // protected
  MemoryCache<ID, User> createUserCache() => ThanosCache();
  MemoryCache<ID, Group> createGroupCache() => ThanosCache();

  /// Call it when received 'UIApplicationDidReceiveMemoryWarningNotification',
  /// this will remove 50% of cached objects
  ///
  /// @return number of survivors
  int reduceMemory() {
    int cnt1 = _userCache.reduceMemory();
    int cnt2 = _groupCache.reduceMemory();
    return cnt1 + cnt2;
  }

  //
  //  Barrack
  //

  @override
  void cacheUser(User user) {
    user.dataSource ??= facebook;
    _userCache.put(user.identifier, user);
  }

  @override
  void cacheGroup(Group group) {
    group.dataSource ??= facebook;
    _groupCache.put(group.identifier, group);
  }

  @override
  User? getUser(ID identifier) => _userCache.get(identifier);

  @override
  Group? getGroup(ID identifier) => _groupCache.get(identifier);

  //
  //  Archivist
  //

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
    Meta? old = await facebook?.getMeta(identifier);
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
      assert(false, 'document not valid: ${doc.identifier}');
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
    Meta? meta = await facebook?.getMeta(doc.identifier);
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
    List<Document>? documents = await facebook?.getDocuments(identifier);
    if (documents == null || documents.isEmpty) {
      return false;
    }
    Document? old = DocumentUtils.lastDocument(documents, type);
    return old != null && DocumentUtils.isExpired(doc, old);
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
    if (docs == null || docs.isEmpty) {
      return null;
    }
    var visa = DocumentUtils.lastVisa(docs);
    // assert(doc != null, 'failed to get visa for: $user');
    return visa?.publicKey;
  }

  @override
  Future<List<ID>> getLocalUsers() async {
    return await database.getLocalUsers();
  }

}
