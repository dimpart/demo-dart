/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
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
import '../dim_utils.dart';

class SQLValues {

  SQLValues.from(Map<String, dynamic> values) {
    for (String key in values.keys) {
      setValue(key, values[key]);
    }
  }

  final List<Pair<String, dynamic>> _values = [];

  void setValue(String name, dynamic value) {
    Pair<String, dynamic> pair;
    int index;
    for (index = _values.length - 1; index >= 0; --index) {
      pair = _values[index];
      if (name == pair.first) {
        break;
      }
    }
    pair = Pair(name, value);
    if (index < 0) {
      _values.add(pair);
    } else {
      _values[index] = pair;
    }
  }

  void appendValues(StringBuffer sb) {
    StringBuffer tmp = StringBuffer();
    for (Pair<String, dynamic> pair in _values) {
      tmp.write(pair.first);
      tmp.write('=');
      appendEscapeValue(tmp, pair.second);
      tmp.write(',');
    }
    if (tmp.isNotEmpty) {
      String str = tmp.toString();
      sb.write(str.substring(0, str.length - 1));  // remove last ','
    }
  }

  static void appendStringList(StringBuffer sb, List<String> array) {
    StringBuffer tmp = StringBuffer();
    for (dynamic item in array) {
      tmp.write(item);
      tmp.write(',');
    }
    if (tmp.isNotEmpty) {
      String str = tmp.toString();
      sb.write(str.substring(0, str.length - 1));  // remove last ','
    }
  }

  static void appendEscapeValueList(StringBuffer sb, List array) {
    StringBuffer tmp = StringBuffer();
    for (dynamic item in array) {
      appendEscapeValue(tmp, item);
      tmp.write(',');
    }
    if (tmp.isNotEmpty) {
      String str = tmp.toString();
      sb.write(str.substring(0, str.length - 1));  // remove last ','
    }
  }

  static void appendEscapeValue(StringBuffer sb, dynamic value) {
    // TODO: other types?
    if (value == null) {
      sb.write('NULL');
    } else if (value is num) {
      sb.write(value);
    } else if (value is String) {
      _appendEscapeString(sb, value);
    } else {
      _appendEscapeString(sb, '$value');
    }
  }

  static void _appendEscapeString(StringBuffer sb, String str) {
    sb.write('\'');
    if (str.contains('\'')) {
      int ch;
      for (int index = 0; index < str.length; ++index) {
        ch = str.codeUnitAt(index);
        if (ch == _sq) {  // '\''
          sb.write('\'');
        }
        sb.writeCharCode(ch);
      }
    } else {
      sb.write(str);
    }
    sb.write('\'');
  }
  static final int _sq = '\''.codeUnitAt(0);

}
