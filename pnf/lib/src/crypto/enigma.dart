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
import 'enigma_item.dart';


/// Enigma for MD5 secrets
class Enigma with ClassNameMixIn {

  final Map<String, EnigmaItem> _table = {};

  String get className => getClassName('Enigma');

  @override
  String toString() {
    String clazz = className;
    String text = '\r\n';
    _table.forEach((key, item) {
      text += '\t$key: $item\r\n';
    });
    return '<$clazz count=$length>$text</$clazz>';
  }

  Iterable<String> get keys => _table.keys.cast();
  Iterable<EnigmaItem> get items => _table.values;

  int get length => _table.length;

  bool get isEmpty => _table.isEmpty;
  bool get isNotEmpty => _table.isNotEmpty;

  EnigmaItem? operator [](Object? key) => _table[key];
  void operator []=(String key, EnigmaItem item) {
    assert(item.isNotEmpty, 'enigma item should not be empty: $key => $item');
    _table[key] = item;
  }

  /// Take all items
  Iterable<EnigmaItem> get all => _table.values;

  /// Take any item
  EnigmaItem? get any {
    var array = _table.values;
    for (var item in array) {
      if (item.isNotEmpty) {
        // got first item not empty
        return item;
      }
    }
    assert(_table.isNotEmpty, 'enigma items not found');
    // NOTICE: the first item may be empty
    return first;
  }

  /// Take first item
  EnigmaItem? get first {
    if (_table.isEmpty) {
      assert(false, 'enigma items not found');
      return null;
    }
    return _table.values.first;
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
  void update(Iterable<EnigmaItem> secrets) {
    for (var item in secrets) {
      assert(item.isNotEmpty, 'enigma item should not be empty: $item');
      _table[item.index] = item;
    }
  }

  /// Search secret with keys
  EnigmaItem? lookup(Iterable keys) {
    if (keys.length == 1 && keys.first == '*') {
      return any;
    }
    EnigmaItem? found;
    // check keys one by one
    EnigmaItem? item;
    for (var prefix in keys) {
      item = _table[prefix];
      if (item == null) {
        // item not exists
        continue;
      }
      found = item;
      if (found.isNotEmpty) {
        // got first item not empty
        break;
      }
      assert(false, 'enigma item empty: $item');
      // continue;
    }
    // NOTICE: the chosen item may be empty
    return found;
  }

}
