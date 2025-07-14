/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import 'dart:typed_data';

import 'package:dimsdk/dimsdk.dart';
import 'package:dimsdk/plugins.dart';
import 'package:dim_plugins/crypto.dart';
import 'package:dim_plugins/format.dart';
import 'package:dim_plugins/plugins.dart';
import 'package:lnc/log.dart';

import '../protocol/ans.dart';
import '../protocol/block.dart';
import '../protocol/customized.dart';
import '../protocol/handshake.dart';
import '../protocol/login.dart';
import '../protocol/mute.dart';
import '../protocol/report.dart';
import '../protocol/search.dart';

import 'address.dart';
import 'entity.dart';
import 'meta.dart';


/// Extensions Loader
/// ~~~~~~~~~~~~~~~~~
class CommonExtensionLoader extends ExtensionLoader {

  @override
  void registerContentFactories() {
    super.registerContentFactories();
    registerCustomizedFactories();
  }

  /// Customized content factories
  // protected
  void registerCustomizedFactories() {

    // Application Customized
    setContentFactory(ContentType.CUSTOMIZED, 'customized', creator: (dict) => AppCustomizedContent(dict));
    setContentFactory(ContentType.APPLICATION, 'application', creator: (dict) => AppCustomizedContent(dict));

  }

  @override
  void registerCommandFactories() {
    super.registerCommandFactories();

    // ANS
    setCommandFactory(AnsCommand.ANS, creator: (dict) => BaseAnsCommand(dict));

    // Handshake
    setCommandFactory(HandshakeCommand.HANDSHAKE, creator: (dict) => BaseHandshakeCommand(dict));
    // Login
    setCommandFactory(LoginCommand.LOGIN, creator: (dict) => BaseLoginCommand(dict));

    // Mute
    setCommandFactory(MuteCommand.MUTE,   creator: (dict) => MuteCommand(dict));
    // Block
    setCommandFactory(BlockCommand.BLOCK, creator: (dict) => BlockCommand(dict));

    // Report: online, offline
    setCommandFactory(ReportCommand.REPORT,  creator: (dict) => BaseReportCommand(dict));
    setCommandFactory(ReportCommand.ONLINE,  creator: (dict) => BaseReportCommand(dict));
    setCommandFactory(ReportCommand.OFFLINE, creator: (dict) => BaseReportCommand(dict));

    // Search: users
    setCommandFactory(SearchCommand.SEARCH,       creator: (dict) => BaseSearchCommand(dict));
    setCommandFactory(SearchCommand.ONLINE_USERS, creator: (dict) => BaseSearchCommand(dict));

  }

}


/// Plugin Loader
/// ~~~~~~~~~~~~~
class CommonPluginLoader extends PluginLoader {

  @override
  void load() {
    Converter.converter = _SafeConverter();
    super.load();
  }

  @override
  void registerIDFactory() {
    ID.setFactory(EntityIDFactory());
  }

  @override
  void registerAddressFactory() {
    Address.setFactory(CompatibleAddressFactory());
  }

  @override
  void registerMetaFactories() {
    var mkm = CompatibleMetaFactory(MetaType.MKM);
    var btc = CompatibleMetaFactory(MetaType.BTC);
    var eth = CompatibleMetaFactory(MetaType.ETH);

    Meta.setFactory('1', mkm);
    Meta.setFactory('2', btc);
    Meta.setFactory('4', eth);

    Meta.setFactory('mkm', mkm);
    Meta.setFactory('btc', btc);
    Meta.setFactory('eth', eth);

    Meta.setFactory('MKM', mkm);
    Meta.setFactory('BTC', btc);
    Meta.setFactory('ETH', eth);
  }

  @override
  void registerBase64Coder() {
    /// Base64 coding
    Base64.coder = _Base64Coder();
  }

  @override
  void registerRSAKeyFactories() {
    /// RSA keys with created time
    var rsaPub = RSAPublicKeyFactory();
    PublicKey.setFactory(AsymmetricAlgorithms.RSA, rsaPub);
    PublicKey.setFactory('SHA256withRSA', rsaPub);
    PublicKey.setFactory('RSA/ECB/PKCS1Padding', rsaPub);

    var rsaPri = _RSAPrivateKeyFactory();
    PrivateKey.setFactory(AsymmetricAlgorithms.RSA, rsaPri);
    PrivateKey.setFactory('SHA256withRSA', rsaPri);
    PrivateKey.setFactory('RSA/ECB/PKCS1Padding', rsaPri);
  }

}

/// Base-64
class _Base64Coder extends Base64Coder {

  @override
  Uint8List? decode(String string) {
    string = trimBase64String(string);
    return super.decode(string);
  }

  static String trimBase64String(String b64) {
    if (b64.contains('\n')) {
      b64 = b64.replaceAll('\n', '');
      b64 = b64.replaceAll('\r', '');
      b64 = b64.replaceAll('\t', '');
      b64 = b64.replaceAll(' ', '');
    }
    return b64.trim();
  }

}

/// RSA factory
class _RSAPrivateKeyFactory extends RSAPrivateKeyFactory {

  @override
  PrivateKey generatePrivateKey() {
    Map key = {'algorithm': AsymmetricAlgorithms.RSA};
    return _RSAPrivateKey(key);
  }

  @override
  PrivateKey? parsePrivateKey(Map key) {
    return _RSAPrivateKey(key);
  }

}

/// RSA key with created time
class _RSAPrivateKey extends RSAPrivateKey {
  _RSAPrivateKey(super.dict) {
    DateTime? time = getDateTime('time');
    if (time == null) {
      time = DateTime.now();
      setDateTime('time', time);
    }
  }

  @override
  PublicKey get publicKey {
    PublicKey key = super.publicKey;
    DateTime? time = getDateTime('time');
    if (time != null) {
      key.setDateTime('time', time);
    }
    return key;
  }

}

/// Safely Converter
class _SafeConverter extends BaseConverter with Logging {

  @override
  bool? getBool(Object? value, bool? defaultValue) {
    try {
      return super.getBool(value, defaultValue);
    } catch (e, st) {
      logError('failed to get bool: $value, error: $e, $st');
      return defaultValue;
    }
  }

  @override
  int? getInt(Object? value, int? defaultValue) {
    try {
      return super.getInt(value, defaultValue);
    } catch (e, st) {
      logError('failed to get int: $value, error: $e, $st');
      return defaultValue;
    }
  }

  @override
  double? getDouble(Object? value, double? defaultValue) {
    try {
      return super.getDouble(value, defaultValue);
    } catch (e, st) {
      logError('failed to get double: $value, error: $e, $st');
      return defaultValue;
    }
  }

  @override
  DateTime? getDateTime(Object? value, DateTime? defaultValue) {
    try {
      return super.getDateTime(value, defaultValue);
    } catch (e, st) {
      logError('failed to get datetime: $value, error: $e, $st');
      return defaultValue;
    }
  }

}
