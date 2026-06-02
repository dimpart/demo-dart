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
import 'dart:math';
import 'dart:typed_data';

import 'package:dimp/dimp.dart';

import 'digest.dart';
import 'template.dart';
import 'item.dart';


/// Enigma for MD5 secrets
class Enigma {

  final Map<String, EnigmaItem> _table = {};

  String get className => 'Enigma';

  @override
  String toString() {
    String clazz = className;
    String keys = _table.keys.toString();
    return '<$clazz>\r\n'
        '    keys: $keys\r\n'
        '</$clazz>';
  }

  /// Take all items
  Iterable<EnigmaItem> get all => _table.values;

  /// Take any item
  EnigmaItem? get any {
    if (_table.isEmpty) {
      assert(false, 'enigma secrets not found');
      return null;
    }
    return _table.entries.first.value;
  }

  /// Remove all secrets
  void clear() =>
      _table.clear();

  /// Remove secrets with keys
  void remove(Iterable<String> keys) {
    // remove keys one by one
    for (String prefix in keys) {
      _table.removeWhere((k, _) => k == prefix);
    }
  }

  /// Update secrets
  void update(Iterable secrets) {
    var array = EnigmaItem.convert(secrets);
    for (var item in array) {
      _table[item.key] = item;
    }
  }

  /// Search secret with keys
  EnigmaItem? lookup(Iterable<String> keys) {
    if (keys.length == 1 && keys.first == '*') {
      return any;
    }
    // check keys one by one
    EnigmaItem? item;
    for (String prefix in keys) {
      item = _table[prefix];
      if (item != null) {
        return item;
      }
    }
    // secret not found
    return null;
  }

  /// Build upload URL
  /// ~~~~~~~~~~~~~~~~
  /// hash algorithm: md5(md5(data) + secret + salt)
  String build(String api, EnigmaItem enigma, {
    required ID sender, required Uint8List data,
  }) {
    assert(data.isNotEmpty && enigma.isNotEmpty, 'enigma params error: ${data.length}, $enigma');
    // build URL string with sender
    String urlString = api;
    urlString = Template.replace(urlString, 'ID', sender.address.toString());
    // hash: md5(md5(data) + secret + salt)
    Uint8List salt = _EnigmaHelper.random(16);
    Uint8List temp = _EnigmaHelper.concat(MD5.digest(data), enigma.secret, salt);
    Uint8List hash = MD5.digest(temp);
    urlString = Template.replace(urlString, 'MD5', Hex.encode(hash));
    urlString = Template.replace(urlString, 'SALT', Hex.encode(salt));
    return _EnigmaHelper.replaceEnigma(urlString, enigma.key);
  }

}


/// Enigma secret formats:
///   1. base64,{BASE64_ENCODE}
///   2. hex,{HEX_ENCODE}
///   3. {HEX_ENCODE}
abstract class _EnigmaHelper {

  //
  //  URL: "https://tfs.dim.chat/{ID}/upload?md5={MD5}&salt={SALT}&enigma={ENIGMA}"
  //

  /// Set enigma key into URL
  /// replace the tag 'enigma' with new key
  static String replaceEnigma(String url, String enigma) {
    if (url.contains('{ENIGMA}')) {
      return Template.replace(url, 'ENIGMA', enigma);
    }
    return Template.replaceQueryParam(url, 'enigma', enigma);
  }

  //
  //  Bytes
  //

  static Uint8List concat(Uint8List a, Uint8List b, Uint8List c) =>
      Uint8List.fromList(a + b + c);

  static Uint8List random(int size) {
    Uint8List data = Uint8List(size);
    Random r = Random();
    for (int i = 0; i < size; ++i) {
      data[i] = r.nextInt(256);
    }
    return data;
  }

}
