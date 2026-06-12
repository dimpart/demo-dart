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


class SQLFields {

  static List<String> standardizeDefinitions(List<String> fields) {
    List<String> lines = [];
    String text;
    int pos;
    String name;
    for (var item in fields) {
      text = item.trim();
      pos = text.indexOf(' ');
      if (pos < 1) {
        assert(text.isEmpty, 'field definition error: $item');
        continue;
      }
      name = text.substring(0, pos);
      text = text.substring(pos);
      // standardizing
      if (_needsStandardize(name)) {
        name = '`$name`';
      }
      lines.add('$name$text');
    }
    return lines;
  }

  static String standardizeClauseFields(String orderBy) {
    List<String> fields = orderBy.split(',');
    List<String> strings = [];
    String text;
    int pos;
    String name;
    for (var item in fields) {
      text = item.trim();
      pos = text.indexOf(' ');
      if (pos > 0) {
        name = text.substring(0, pos);
        text = text.substring(pos);
      } else {
        name = text;
        text = '';
      }
      // standardizing
      if (_needsStandardize(name)) {
        name = '`$name`';
      }
      strings.add('$name$text');
    }
    return strings.join(', ');
  }

  static List<String> standardizeColumns(List<String> columns) {
    List<String> strings = [];
    String name;
    for (var item in columns) {
      name = item.trim();
      // standardizing
      if (_needsStandardize(name)) {
        name = '`$name`';
      }
      strings.add(name);
    }
    return strings;
  }

  static String standardizeName(String name) {
    name = name.trim();
    // standardizing
    if (_needsStandardize(name)) {
      name = '`$name`';
    }
    return name;
  }

  static bool _needsStandardize(String name) => _reg.hasMatch(name);

  static final _reg = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

}
