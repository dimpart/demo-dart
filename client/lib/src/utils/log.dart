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

class Log {

  static const String kRed    = '\x1B[95m';
  static const String kYellow = '\x1B[93m';
  static const String kGreen  = '\x1B[92m';
  static const String kClear  = '\x1B[0m';

  static const int kDebugFlag   = 1 << 0;
  static const int kInfoFlag    = 1 << 1;
  static const int kWarningFlag = 1 << 2;
  static const int kErrorFlag   = 1 << 3;

  static const int kDebug   = kDebugFlag|kInfoFlag|kWarningFlag|kErrorFlag;
  static const int kDevelop =            kInfoFlag|kWarningFlag|kErrorFlag;
  static const int kRelease =                      kWarningFlag|kErrorFlag;

  static int level = kRelease;

  static int chunkLength = 1000;
  static int limitLength = -1;    // -1 means unlimited

  static String get _now {
    DateTime current = DateTime.now();
    return Time.getFullTimeString(current);
  }

  static String get _location {
    List<String> caller = _caller(StackTrace.current);
    // String func = caller[0];
    String text = caller[1].substring(1, caller[1].lastIndexOf(':'));
    int pos = text.lastIndexOf(':');
    String line = text.substring(pos + 1);
    String file = text.substring(text.lastIndexOf('/') + 1, pos);
    return '$file:$line';
  }

  static void colorPrint(String body, {required String color}) {
    _print(body, head: color, tail: kClear);
  }
  static void _print(String body, {String head = '', String tail = ''}) {
    int size = body.length;
    if (0 < limitLength && limitLength < size) {
      body = '${body.substring(0, limitLength - 3)}...';
      size = limitLength;
    }
    int start = 0, end = chunkLength;
    for (; end < size; start = end, end += chunkLength) {
      print(head + body.substring(start, end) + tail + _chunked);
    }
    if (start >= size) {
      // all chunks printed
      assert(start == size, 'should not happen');
    } else if (start == 0) {
      // body too short
      print(head + body + tail);
    } else {
      // print last chunk
      print(head + body.substring(start) + tail);
    }
  }
  static const String _chunked = '↩️';

  static void debug(String? msg) {
    if ((level & kDebugFlag) == 0) {
      return;
    }
    _print('[$_now]  DEBUG  | $_location >\t$msg', head: kGreen, tail: kClear);
  }

  static void info(String? msg) {
    if ((level & kInfoFlag) == 0) {
      return;
    }
    _print('[$_now]         | $_location >\t$msg');
  }

  static void warning(String? msg) {
    if ((level & kWarningFlag) == 0) {
      return;
    }
    _print('[$_now] WARNING | $_location >\t$msg', head: kYellow, tail: kClear);
  }

  static void error(String? msg) {
    if ((level & kErrorFlag) == 0) {
      return;
    }
    _print('[$_now]  ERROR  | $_location >\t$msg', head: kRed, tail: kClear);
  }

}

// #0      Log._location (package:dim_client/src/common/utils/log.dart:52:46)
// #2      main.<anonymous closure> (file:///.../client_test.dart:16:11)
// #?      function (path:1:2)
List<String> _caller(StackTrace current) {
  String text = current.toString().split('\n')[2];
  // skip '#0      '
  int pos = text.indexOf(' ');
  text = text.substring(pos).trimLeft();
  // split 'function' & '(file:line:column)'
  pos = text.lastIndexOf(' ');
  return[text.substring(0, pos), text.substring(pos + 1)];
}


class Time {

  static int get currentTimeMillis => DateTime.now().millisecondsSinceEpoch;

  /// yyyy-MM-dd HH:mm:ss
  static String getFullTimeString(DateTime time) {
    String m = _twoDigits(time.month);
    String d = _twoDigits(time.day);
    String h = _twoDigits(time.hour);
    String min = _twoDigits(time.minute);
    String sec = _twoDigits(time.second);
    return '${time.year}-$m-$d $h:$min:$sec';
  }

  static String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }
}
