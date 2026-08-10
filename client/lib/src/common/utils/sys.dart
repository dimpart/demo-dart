/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2026 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2026 Albert Moky
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
import 'package:dim_plugins/crypto.dart';
import 'package:lnc/log.dart';


abstract interface class AssetLoader {

  /// Retrieve a string from the asset bundle.
  ///
  /// Throws an exception if the asset is not found.
  ///
  /// If the `cache` argument is set to false, then the data will not be
  /// cached, and reading the data may bypass the cache. This is useful if the
  /// caller is going to be doing its own caching. (It might not be cached if
  /// it's set to true either, depending on the asset bundle implementation.)
  ///
  /// The function expects the stored string to be UTF-8-encoded as
  /// [Utf8Codec] will be used for decoding the string. If the string is
  /// larger than 50 KB, the decoding process is delegated to an
  /// isolate to avoid jank on the main thread.
  Future<String> loadString(String key, {bool cache = true});

}


/// System Environments
class SysEnv with Logging {
  factory SysEnv() => _instance;
  static final SysEnv _instance = SysEnv._internal();
  SysEnv._internal();

  final Map<String, String> _texts = {};  // cache for text file contents
  final Map<String, Map> _tables = {};    // cache for json file contents

  AssetLoader? _loader;

  // ignore: non_constant_identifier_names
  final String SETTINGS = 'assets/settings.json';

  void setAssetLoader(AssetLoader assetLoader) => _loader = assetLoader;

  /// load text file content from "assets/*"
  Future<String> loadString(final String path, {bool cache = true}) async {
    String? text;
    // 1. check cache
    if (cache) {
      text = _texts[path];
      if (text != null) {
        return text;
      }
    }
    // 2. cache not found, try to load text file
    text = await _loader!.loadString(path, cache: cache);
    _texts[path] = text;
    return text;
  }

  void cacheString(final String path, {required String content}) {
    assert(_texts[path] == null, 'text file content conflicts: $path');
    _texts[path] = content;
  }

  String? getString(final String path) {
    assert(_texts[path] != null, 'text file content not exists: $path');
    return _texts[path];
  }

  Map? getMap(final String path) {
    Map? info = _tables[path];
    if (info == null) {
      String? json = _texts[path];
      if (json != null) {
        info = JSONMap.decode(json);
        if (info != null) {
          _tables[path] = info;
        }
      }
    }
    return info;
  }

  Map? getSettings(String name) {
    final path = 'assets/$name.json';
    Map? info = getMap(path);
    if (info == null) {
      // get from main settings
      info = getMap(SETTINGS)?[name];
      if (info != null) {
        // update cache
        _tables[path] = info;
      }
    }
    return info;
  }

  //
  //  Enigma secret keys
  //

  Map? get enigma => getSettings('enigma');

  /// secret keys
  List get enigmaSecrets {
    Map? info = enigma;
    var keys = info?['secrets'];
    if (keys is List && keys.isNotEmpty) {
      logInfo('got enigma secrets: $keys');
      return keys;
    }
    assert(false, 'enigma secrets not found: $info');
    return [];
  }

  //
  //  App Distribution Channel
  //

  Map? get store => getSettings('store');

  /// app store name
  String get storeName {
    Map? info = store;
    var channel = info?['name'];
    if (channel is String && channel.isNotEmpty) {
      logInfo('got distribution channel (app store): "$channel"');
      return channel;
    }
    assert(false, 'store name not found: $info');
    return 'store.mopo.com';  // "apps.apple.com", "play.google.com", ...
  }

  //
  //  terminal (device name)
  //

  String? _terminal;  // encode(device)

  /// terminal for current user
  String get terminal {
    String? device = _terminal;
    assert(device != null && device.isNotEmpty, 'terminal (device) not initialized.');
    return device ?? 'AquilaRift';
  }

  set terminal(String device) => _terminal = device;

}
