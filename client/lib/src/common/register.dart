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
import 'dart:math';
import 'dart:typed_data';

import 'package:dimsdk/dimsdk.dart';

import 'dbi/account.dart';

class Register {
  Register(this.database);

  final AccountDBI database;

  ///  Generate user account
  ///
  /// @param nickname  - user name
  /// @param avatarUrl - photo URL
  /// @return user ID
  Future<ID> createUser({required String name, PortableNetworkFile? avatar}) async {
    //
    //  Step 1: generate private key (with asymmetric algorithm)
    //
    PrivateKey idKey = PrivateKey.generate(AsymmetricAlgorithms.ECC)!;
    //
    //  Step 2: generate meta with private key (and meta seed)
    //
    Meta meta = Meta.generate(MetaType.ETH, idKey);
    //
    //  Step 3: generate ID with meta
    //
    ID identifier = ID.generate(meta, EntityType.USER);
    //
    //  Step 4: generate visa with ID and sign with private key
    //
    PrivateKey? msgKey = PrivateKey.generate(AsymmetricAlgorithms.RSA);
    EncryptKey visaKey = msgKey!.publicKey as EncryptKey;
    Visa visa = createVisa(identifier, visaKey, idKey, name: name, avatar: avatar);
    //
    //  Step 5: save private key, meta & visa in local storage
    //
    await database.savePrivateKey(idKey, PrivateKeyDBI.kMeta, identifier, decrypt: 0);
    await database.savePrivateKey(msgKey, PrivateKeyDBI.kVisa, identifier, decrypt: 1);
    await database.saveMeta(meta, identifier);
    await database.saveDocument(visa);
    // OK
    return identifier;
  }

  ///  Generate group account
  ///
  /// @param founder - group founder
  /// @param title   - group name
  /// @param seed    - ID.name
  /// @return group ID
  Future<ID> createGroup(ID founder, {required String name, String? seed}) async {
    if (seed == null || seed.isEmpty) {
      Random random = Random();
      int r = random.nextInt(999990000) + 10000; // 10,000 ~ 999,999,999
      seed = 'Group-$r';
    }
    //
    //  Step 1: get private key of founder
    //
    SignKey privateKey = (await database.getPrivateKeyForVisaSignature(founder))!;
    //
    //  Step 2: generate meta with private key (and meta seed)
    //
    Meta meta = Meta.generate(MetaType.MKM, privateKey, seed: seed);
    //
    //  Step 3: generate ID with meta
    //
    ID identifier = ID.generate(meta, EntityType.GROUP);
    //
    //  Step 4: generate bulletin with ID and sign with founder's private key
    //
    Bulletin doc = createBulletin(identifier, privateKey, name: name, founder: founder);
    //
    //  Step 5: save meta & bulletin in local storage
    //
    await database.saveMeta(meta, identifier);
    await database.saveDocument(doc);
    //
    //  Step 6: add founder as first member
    //
    List<ID> members = [founder];
    await database.saveMembers(members, group: identifier);
    // OK
    return identifier;
  }

  // create user document
  static Visa createVisa(ID identifier, EncryptKey visaKey, SignKey idKey,
      {required String name, PortableNetworkFile? avatar}) {
    assert(identifier.isUser, 'user ID error: $identifier');
    Visa doc = BaseVisa.from(identifier);
    // App ID
    doc.setProperty('app_id', 'chat.dim.tarsier');
    // nickname
    doc.name = name;
    // avatar
    if (avatar != null) {
      doc.avatar = avatar;
    }
    // public key
    doc.publicKey = visaKey;
    // sign it
    Uint8List? sig = doc.sign(idKey);
    assert(sig != null, 'failed to sign visa: $identifier');
    return doc;
  }
  // create group document
  static Bulletin createBulletin(ID identifier, SignKey privateKey,
      {required String name, required ID founder}) {
    assert(identifier.isGroup, 'group ID error: $identifier');
    Bulletin doc = BaseBulletin.from(identifier);
    // App ID
    doc.setProperty('app_id', 'chat.dim.tarsier');
    // group founder
    doc.setProperty('founder', founder.toString());
    // group name
    doc.name = name;
    // sign it
    Uint8List? sig = doc.sign(privateKey);
    assert(sig != null, 'failed to sign bulletin: $identifier');
    return doc;
  }

}
