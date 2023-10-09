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

import 'package:dimp/dimp.dart';
import 'package:dimsdk/dimsdk.dart';
import 'package:dim_plugins/dim_plugins.dart';

import 'compat/entity.dart';
import 'compat/meta.dart';
import 'dbi/account.dart';
import 'protocol/handshake.dart';
import 'protocol/login.dart';
import 'protocol/report.dart';
import 'protocol/mute.dart';
import 'protocol/block.dart';
import 'protocol/ans.dart';

class Register {
  Register(AccountDBI adb) : _database = adb;

  final AccountDBI _database;

  AccountDBI get database => _database;

  ///  Generate user account
  ///
  /// @param nickname  - user name
  /// @param avatarUrl - photo URL
  /// @return user ID
  Future<ID> createUser({required String name, String? avatar}) async {
    //
    //  Step 1: generate private key (with asymmetric algorithm)
    //
    PrivateKey idKey = PrivateKey.generate(AsymmetricKey.kECC)!;
    //
    //  Step 2: generate meta with private key (and meta seed)
    //
    Meta meta = Meta.generate(MetaType.kETH, idKey);
    //
    //  Step 3: generate ID with meta
    //
    ID identifier = ID.generate(meta, EntityType.kUser);
    //
    //  Step 4: generate visa with ID and sign with private key
    //
    PrivateKey msgKey = PrivateKey.generate(AsymmetricKey.kRSA)!;
    Visa visa = _createVisa(identifier, msgKey.publicKey as EncryptKey, idKey,
        name: name, avatar: avatar);
    //
    //  Step 5: save private key, meta & visa in local storage
    //          don't forget to upload them onto the DIM station
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
    Meta meta = Meta.generate(MetaType.kMKM, privateKey, seed: seed);
    //
    //  Step 3: generate ID with meta
    //
    ID identifier = ID.generate(meta, EntityType.kGroup);
    //
    //  Step 4: generate bulletin with ID and sign with founder's private key
    //
    Bulletin doc = _createBulletin(identifier, privateKey, name: name, founder: founder);
    //
    //  Step 5: save meta & bulletin in local storage
    //          don't forget to upload then onto the DIM station
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
  static Visa _createVisa(ID identifier, EncryptKey visaKey, SignKey idKey,
      {required String name, String? avatar}) {
    assert(identifier.isUser, 'user ID error: $identifier');
    Visa doc = BaseVisa.from(identifier);
    // App ID
    doc.setProperty('app_id', 'chat.dim.tarsier');
    // nickname
    doc.name = name;
    // avatar
    if (avatar != null) {
      doc.avatar = PortableNetworkFile.parse(avatar);
    }
    // public key
    doc.publicKey = visaKey;
    // sign it
    Uint8List? sig = doc.sign(idKey);
    assert(sig != null, 'failed to sign visa: $identifier');
    return doc;
  }
  // create group document
  static Bulletin _createBulletin(ID identifier, SignKey privateKey,
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

  static void prepare() {
    if (_loaded) {
      return;
    }

    // load plugins
    registerPlugins();
    registerEntityIDFactory();
    registerCompatibleAddressFactory();
    registerCompatibleMetaFactories();

    // load message/content factories
    _registerFactories();

    _loaded = true;
  }
  static bool _loaded = false;
}

void _registerFactories() {
  //
  //  Register core factories
  //
  registerAllFactories();

  // Handshake
  Command.setFactory(HandshakeCommand.kHandshake, CommandParser((dict) => BaseHandshakeCommand(dict)));
  // Login
  Command.setFactory(LoginCommand.kLogin, CommandParser((dict) => BaseLoginCommand(dict)));
  // Report
  Command.setFactory(ReportCommand.kReport, CommandParser((dict) => BaseReportCommand(dict)));
  // Mute
  Command.setFactory(MuteCommand.kMute, CommandParser((dict) => MuteCommand(dict)));
  // Block
  Command.setFactory(BlockCommand.kBlock, CommandParser((dict) => BlockCommand(dict)));
  // ANS
  Command.setFactory(AnsCommand.kANS, CommandParser((dict) => BaseAnsCommand(dict)));
}
