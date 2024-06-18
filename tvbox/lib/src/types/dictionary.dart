/* license: https://mit-license.org
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
import 'comparator.dart';


/// Map Info
abstract class Dictionary {
  Dictionary(Map? dict) : _map = dict ?? {};

  final Map _map;

  dynamic getValue(String key, dynamic defaultValue) {
    return _map[key] ?? defaultValue;
  }

  void setValue(String key, dynamic value) {
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

  // @override
  Map toMap() => _map;

  @override
  String toString() => _map.toString();

  @override
  bool operator ==(Object other) {
    if (other is Dictionary) {
      if (identical(this, other)) {
        // same object
        return true;
      }
      // compare with inner map
      other = other.toMap();
    }
    return other is Map && Comparator.mapEquals(other, _map);
  }

  @override
  int get hashCode => _map.hashCode;

  ///
  ///   Map<String, dynamic>
  ///

  // @override
  bool containsValue(dynamic value) => _map.containsValue(value);

  // @override
  bool containsKey(Object? key) => _map.containsKey(key);

  // @override
  dynamic operator [](Object? key) => _map[key];

  // @override
  void operator []=(String key, dynamic value) => _map[key] = value;

  // @override
  Iterable<MapEntry<String, dynamic>> get entries => _map.entries.cast();

  // @override
  void removeWhere(bool Function(String key, dynamic value) test) =>
      _map.removeWhere((key, value) => test(key, value));

  // @override
  dynamic remove(Object? key) => _map.remove(key);

  // @override
  void clear() => _map.clear();

  // @override
  void forEach(void Function(String key, dynamic value) action) =>
      _map.forEach((key, value) => action);

  // @override
  Iterable<String> get keys => _map.keys.cast();

  // @override
  Iterable get values => _map.values;

  // @override
  int get length => _map.length;

  // @override
  bool get isEmpty => _map.isEmpty;

  // @override
  bool get isNotEmpty => _map.isNotEmpty;

}
