/* license: https://mit-license.org
 *
 *  Cryptography
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

import 'package:dimp/dimp.dart';
import 'package:object_key/object_key.dart';


class EnigmaItem {
  EnigmaItem(this.key, this.secret);

  final String key;
  final Uint8List secret;

  bool get isEmpty => secret.isEmpty;
  bool get isNotEmpty => secret.isNotEmpty;

  String get className => 'Enigma';

  @override
  String toString() {
    String clazz = className;
    return '<$clazz key="$key" length=${secret.length} />';
  }

  //
  //  Conveniences
  //

  static List<EnigmaItem> convert(Iterable array) {
    List<EnigmaItem> items = [];
    EnigmaItem? enigma;
    for (var item in array) {
      enigma = parse(item);
      if (enigma == null) {
        continue;
      }
      items.add(enigma);
    }
    return items;
  }

  //
  //  Factory methods
  //

  static EnigmaItem? parse(Object? enigma) {
    if (enigma == null) {
      return null;
    } else if (enigma is EnigmaItem) {
      return enigma;
    }
    var pair = _fetchEnigmaItem(enigma);
    if (pair == null) {
      assert(false, 'enigma error: $enigma');
      return null;
    }
    var ted = TransportableData.parse(pair.second);
    Uint8List? secret = ted?.bytes;
    if (secret == null/* || secret.isEmpty*/) {
      assert(false, 'enigma value error: $enigma');
      return null;
    }
    return EnigmaItem(pair.first, secret);
  }

  static Pair<String, Object>? _fetchEnigmaItem(Object item) {
    if (item is Map) {
      // parse from map info
      return _fetchFromMap(item);
    } else if (item is String) {
      // parse from Hex string
      return _fetchFromString(item);
    } else {
      assert(false, 'enigma item error: $item');
      return null;
    }
  }

  static Pair<String, Object>? _fetchFromString(String item) {
    String body;
    int pos = item.indexOf(',');
    if (pos > 0) {
      // "base64,..."
      // "hex,..."
      body = item.substring(pos + 1);
    } else if (item.startsWith('0x')) {
      // "0x..."
      body = item.substring(2);
    } else {
      body = item;
    }
    if (body.length < 8) {
      assert(false, 'enigma item error: $item');
      return null;
    }
    String key = body.substring(0, 6);
    return Pair(key, item);
  }

  static Pair<String, Object>? _fetchFromMap(Map item) {
    var key = item['key'];
    var value = item['value'];
    if (value == null) {
      assert(false, 'enigma item value error: $item');
      return null;
    } else if (key is String && key.isNotEmpty) {
      return Pair(key, value);
    } else {
      assert(false, 'enigma item error: $item');
      return null;
    }
  }

}
