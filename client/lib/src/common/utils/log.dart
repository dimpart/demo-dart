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

  static const int kDebugFlag   = 1 << 0;
  static const int kInfoFlag    = 1 << 1;
  static const int kWarningFlag = 1 << 2;
  static const int kErrorFlag   = 1 << 3;

  static const int kDebug   = kDebugFlag|kInfoFlag|kWarningFlag|kErrorFlag;
  static const int kDevelop =            kInfoFlag|kWarningFlag|kErrorFlag;
  static const int kRelease =                      kWarningFlag|kErrorFlag;

  static int level = kRelease;

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

  static void debug(String? msg) {
    if ((level & kDebugFlag) == 0) {
      return;
    }
    print('\x1B[92m[$_now]  DEBUG  | $_location >\t$msg\x1B[0m');
  }

  static void info(String? msg) {
    if ((level & kInfoFlag) == 0) {
      return;
    }
    print('[$_now]         | $_location >\t$msg');
  }

  static void warning(String? msg) {
    if ((level & kWarningFlag) == 0) {
      return;
    }
    print('\x1B[93m[$_now] WARNING | $_location >\t$msg\x1B[0m');
  }

  static void error(String? msg) {
    if ((level & kErrorFlag) == 0) {
      return;
    }
    print('\x1B[95m[$_now]  ERROR  | $_location >\t$msg\x1B[0m');
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
