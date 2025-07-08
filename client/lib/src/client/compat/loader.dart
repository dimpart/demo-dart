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
import 'package:dimsdk/plugins.dart';
import 'package:dim_plugins/plugins.dart';

import '../../common/compat/entity.dart';
import '../../common/compat/loader.dart';

import '../facebook.dart';


class LibraryLoader {
  LibraryLoader({ExtensionLoader? extensionLoader, PluginLoader? pluginLoader}) {
    this.extensionLoader = extensionLoader ?? CommonExtensionLoader();
    this.pluginLoader = pluginLoader ?? ClientPluginLoader();
  }

  late final ExtensionLoader extensionLoader;
  late final PluginLoader pluginLoader;

  void run() {
    extensionLoader.run();
    pluginLoader.run();
  }

}


class ClientPluginLoader extends CommonPluginLoader {

  @override
  void registerIDFactory() {
    ID.setFactory(_IdentifierFactory());
  }

}

IDFactory _identifierFactory = EntityIDFactory();

class _IdentifierFactory implements IDFactory {

  @override
  ID generateIdentifier(Meta meta, int? network, {String? terminal}) {
    return _identifierFactory.generateIdentifier(meta, network, terminal: terminal);
  }

  @override
  ID createIdentifier({String? name, required Address address, String? terminal}) {
    return _identifierFactory.createIdentifier(name: name, address: address, terminal: terminal);
  }

  @override
  ID? parseIdentifier(String identifier) {
    // try ANS record
    ID? id = ClientFacebook.ans?.identifier(identifier);
    if (id != null) {
      return id;
    }
    // parse by original factory
    return _identifierFactory.parseIdentifier(identifier);
  }

}
