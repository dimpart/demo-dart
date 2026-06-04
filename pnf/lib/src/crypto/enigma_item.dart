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


mixin ClassNameMixIn {

  String getClassName(String className) {
    assert(() {
      className = runtimeType.toString();
      return true;
    }());
    return className;
  }

}


class EnigmaItem extends Dictionary with ClassNameMixIn {
  EnigmaItem(Map item) : super(item);

  /// Enigma secret formats:
  ///   0. {BASE64_ENCODE}
  ///   1. base64,{BASE64_ENCODE}
  ///   2. hex,{HEX_ENCODE}
  ///   3. 0x{HEX_ENCODE}
  TransportableData? _data;

  // protected
  TransportableData? get data {
    var ted = _data;
    if (ted == null) {
      var txt = this['secret'] ?? this['value'] ?? this['data'];
      ted = TransportableData.parse(txt);
      _data = ted;
    }
    return ted;
  }

  /// enigma key
  String get index =>
      Converter.getString(this['index'] ?? this['key'] ?? this['name']) ?? '';

  /// enigma value
  Uint8List? get secret => data?.bytes;

  @override
  bool get isEmpty => secret?.isEmpty != false;

  @override
  bool get isNotEmpty => secret?.isNotEmpty == true;

  String get className => getClassName('EnigmaItem');

  @override
  String toString() {
    String clazz = className;
    var size = data?.lengthInBytes;
    return '<$clazz index="$index" length=$size />';
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

  static List<Map> revert(Iterable<EnigmaItem> items) {
    List<Map> array = [];
    for (EnigmaItem enigma in items) {
      array.add(enigma.toMap());
    }
    return array;
  }

  //
  //  Factory method
  //

  static EnigmaItem? parse(Object? enigma) {
    if (enigma == null) {
      return null;
    } else if (enigma is EnigmaItem) {
      return enigma;
    }
    Map info;
    if (enigma is Mapper) {
      info = enigma.toMap();
    } else if (enigma is Map) {
      info = enigma;
    } else {
      assert(false, 'enigma item error: $enigma');
      return null;
    }
    assert(info.containsKey('index') || info.containsKey('key'), 'enigma key not found: $enigma');
    assert(info.containsKey('secret') || info.containsKey('value'), 'enigma value not found: $enigma');
    return EnigmaItem(info);
  }

}
