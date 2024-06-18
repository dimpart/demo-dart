/* license: https://mit-license.org
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
import 'dart:typed_data';


abstract interface class Comparator {

  static bool different(dynamic a, dynamic b) {
    if (a == null) {
      return b != null;
    } else if (b == null) {
      return true;
    } else if (identical(a, b)) {
      // same object
      return false;
    } else if (a is Map) {
      // check key-values
      return !(b is Map && mapEquals(a, b));
    } else if (a is List) {
      // check items
      return !(b is List && listEquals(a, b));
    } else {
      // other types
      return a != b;
    }
  }

  static bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (identical(a, b)) {
      // same object
      return true;
    } else if (a.length != b.length) {
      // different size
      return false;
    }
    for (K key in a.keys) {
      // check values
      if (different(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }

  static bool listEquals<T>(List<T> a, List<T> b) {
    // byte
    if (a is Uint8List) {
      return b is Uint8List && Arrays.equals(a, b);
    } else if (a is Int8List) {
      return b is Int8List && Arrays.equals(a, b);
    }
    // short
    if (a is Uint16List) {
      return b is Uint16List && Arrays.equals(a, b);
    } else if (a is Int16List) {
      return b is Int16List && Arrays.equals(a, b);
    }
    // int
    if (a is Uint32List) {
      return b is Uint32List && Arrays.equals(a, b);
    } else if (a is Int32List) {
      return b is Int32List && Arrays.equals(a, b);
    }
    // long
    if (a is Uint64List) {
      return b is Uint64List && Arrays.equals(a, b);
    } else if (a is Int64List) {
      return b is Int64List && Arrays.equals(a, b);
    }
    // float
    if (a is Float32List) {
      return b is Float32List && Arrays.equals(a, b);
    } else if (a is Float64List) {
      return b is Float64List && Arrays.equals(a, b);
    }
    // others
    if (identical(a, b)) {
      // same object
      return true;
    } else if (a.length != b.length) {
      // different size
      return false;
    }
    for (int index = 0; index < a.length; ++index) {
      // check elements
      if (different(a[index], b[index])) {
        return false;
      }
    }
    return true;
  }

}

abstract interface class Arrays {

  static bool equals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) {
      // same object
      return true;
    } else if (a.length != b.length) {
      // different size
      return false;
    }
    for (int index = 0; index < a.length; ++index) {
      // check values
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

}
