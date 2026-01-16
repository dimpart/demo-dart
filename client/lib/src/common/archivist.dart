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
import 'mkm/bot.dart';
import 'mkm/provider.dart';
import 'mkm/station.dart';
import 'mkm/utils.dart';
import 'utils/cache.dart';

class CommonArchivist with Logging implements Archivist, Barrack {
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

  @override
  User? createUser(ID identifier) {
    assert(identifier.isUser, 'user ID error: $identifier');
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
  Group? createGroup(ID identifier) {
    assert(identifier.isGroup, 'group ID error: $identifier');
    int network = identifier.type;
    // check group type
    if (network == EntityType.ISP) {
      return ServiceProvider(identifier);
    }
    // general group, or 'everyone@everywhere'
    return BaseGroup(identifier);
  }

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
  Future<bool> saveDocument(Document doc, ID identifier) async {
    //
    //  1. check valid
    //
    if (await checkDocumentValid(doc, identifier)) {
      // document valid
    } else {
      assert(false, 'document not valid: $identifier');
      return false;
    }
    //
    //  2. check expired
    //
    if (await checkDocumentExpired(doc, identifier)) {
      logInfo('drop expired document: $doc');
      return false;
    }
    //
    //  3. save into database
    //
    return await database.saveDocument(doc, identifier);
  }

  // protected
  Future<bool> checkDocumentValid(Document doc, ID identifier) async {
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
    return await verifyDocument(doc, identifier);
  }

  // protected
  Future<bool> verifyDocument(Document doc, ID identifier) async {
    // if (doc.isValid) {
    //   return true;
    // }
    // ID? did = ID.parse(doc['did']);
    // if (did == null) {
    //   assert(false, 'document ID not found: $doc');
    //   return false;
    // } else if (did.address != identifier.address) {
    //   // ID not matched
    //   return false;
    // }

    // verify with meta.key
    Meta? meta = await facebook?.getMeta(identifier);
    if (meta == null) {
      logWarning('failed to get meta: $identifier');
      return false;
    }
    return doc.verify(meta.publicKey);
  }

  // protected
  Future<bool> checkDocumentExpired(Document doc, ID identifier) async {
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
  Future<List<ID>> getLocalUsers() async {
    return await database.getLocalUsers();
  }

}
