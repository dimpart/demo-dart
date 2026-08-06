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
import 'package:dimsdk/dimsdk.dart';
import 'package:dim_plugins/dim_plugins.dart';

import '../../common/compat/entity.dart';
import '../../common/compat/loader.dart';

import '../../common/protocol/chats.dart';
import '../../common/protocol/groups.dart';
import '../cpu/app/chats.dart';
import '../cpu/app/filter.dart';
import '../cpu/app/group.dart';
import '../facebook.dart';

import 'hex.dart';


class LibraryLoader {
  LibraryLoader({ExtensionLoader? extensionLoader, PluginLoader? pluginLoader}) {
    this.extensionLoader = extensionLoader ?? ClientExtensionLoader();
    this.pluginLoader = pluginLoader ?? ClientPluginLoader();
  }

  late final ExtensionLoader extensionLoader;
  late final PluginLoader pluginLoader;

  bool _loaded = false;

  void run() {
    if (_loaded) {
      // no need to load it again
      return;
    } else {
      // mark it to loaded
      _loaded = true;
    }
    // try to load all plugins
    load();
  }

  // protected
  void load() {
    extensionLoader.load();
    pluginLoader.load();
  }

}


///
///  Extensions Loader
///


class ClientExtensionLoader extends CommonExtensionLoader {

  @override
  void load() {
    super.load();

    registerMessagePackerFactory();

    registerCustomizedHandlers();

  }

  @override
  void registerIDFactory() {
    ID.setFactory(_IdentifierFactory());
  }

  // protected
  void registerMessagePackerFactory() {
    // fix for 'message.key'
    sharedMessageExtensions.packerFactory = _MessagePackerFactory();
  }

  // protected
  void registerCustomizedHandlers() {

    var filter = sharedMessageExtensions.customizedFilter;
    if (filter is! AppCustomizedFilter) {
      filter = AppCustomizedFilter();
      sharedMessageExtensions.customizedFilter = filter;
    }

    // 'chat.dim.group:history'
    filter.setContentHandler(
      app: GroupHistory.APP,
      mod: GroupHistory.MOD,
      handler: GroupHistoryHandler(),
    );

    // 'chat.dim.messenger'
    filter.setContentHandler(
      app: SyncChatContent.APP,
      mod: SyncChatContent.MOD,
      handler: ChatHistoryHandler(),
    );

  }

  // TODO: other extensions

}


class _MessagePackerFactory extends MessagePackerFactory {

  @override
  SecureMessagePacker createSecureMessagePacker(SecureMessageDelegate delegate) =>
      _SecureMessagePacker(delegate);

}

class _SecureMessagePacker extends SecureMessagePacker {
  _SecureMessagePacker(super.messenger);

  @override
  Future<EncryptedBundle?> decodeKeys(SecureMessage sMsg, ID receiver) async {
    Map? msgKeys = sMsg.encryptedKeys;
    if (msgKeys == null) {
      // get from 'key'
      var base64 = sMsg['key'];
      if (base64 == null) {
        // broadcast message?
        // reused key?
        return null;
      }
      msgKeys = {
        receiver.toString(): base64,
      };
    }
    SecureMessageDelegate? transformer = delegate;
    assert(transformer != null, 'secure message delegate not found');
    return await transformer?.decodeKeys(msgKeys, receiver, sMsg);
  }

  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg, ID receiver) async {
    InstantMessage? iMsg = await super.decryptMessage(sMsg, receiver);
    if (iMsg != null) {
      iMsg.remove('key');
    }
    return iMsg;
  }

}


IDFactory _identifierFactory = EntityIDFactory();

class _IdentifierFactory implements IDFactory {

  @override
  ID generateID(Meta meta, int? network, {String? terminal}) {
    return _identifierFactory.generateID(meta, network, terminal: terminal);
  }

  @override
  ID createID({String? name, required Address address, String? terminal}) {
    return _identifierFactory.createID(name: name, address: address, terminal: terminal);
  }

  @override
  ID? parseID(String identifier) {
    // try ANS record
    ID? id = ClientFacebook.ans?.identifier(identifier);
    if (id != null) {
      return id;
    }
    // parse by original factory
    return _identifierFactory.parseID(identifier);
  }

}


///
///  Plugins Loader
///


class ClientPluginLoader extends CommonPluginLoader {

  @override
  void registerTEDFactory() {

    var ted = _NetworkDataFactory();
    TransportableData.setFactory(ted);

  }

  // TODO: other plugins

}

class _NetworkDataFactory extends BaseNetworkDataFactory {

  @override
  TransportableData? parseTransportableData(String ted) {
    if (ted.startsWith('base64,')) {
      // "base64,..."
      return Base64Data.createWithString(ted.substring(7));
    } else if (ted.startsWith('hex,')) {
      // "hex,..."
      return HexData.createWithString(ted.substring(4));
    // } else if (ted.startsWith('0x')) {
    //   // "0x..."
    //   return HexData.createWithString(ted.substring(2));
    }
    // default
    return super.parseTransportableData(ted);
  }

}
