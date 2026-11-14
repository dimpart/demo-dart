/* license: https://mit-license.org
 *
 *  LNC : Log, Notification & Cache
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
import 'caller.dart';


class LogPrinter {

  static int chunkLength = 1000;  // split output when it's too long
  static int limitLength = -1;    // max output length, -1 means unlimited

  static String carriageReturn = '↩️';

  /// colorful print
  void output(String body, {
    String head = '', String tail = '',
    required String tag, required LogCaller caller,
  }) {
    int size = body.length;
    if (0 < limitLength && limitLength < size) {
      body = '${body.substring(0, limitLength - 4)} ...';
      size = limitLength;
    }
    String x;
    // print chunks
    int start = 0, end = chunkLength;
    for (; end < size; start = end, end += chunkLength) {
      x = head + body.substring(start, end) + tail + carriageReturn;
      println(x, tag: tag, caller: caller);
    }
    if (start > 0) {
      // print last chunk
      x = head + body.substring(start) + tail;
    } else {
      // too short, print the whole message
      x = head + body + tail;
    }
    println(x, tag: tag, caller: caller);
  }

  /// override for redirecting outputs
  // protected
  void println(String x, {
    required String tag, required LogCaller caller,
  }) => print(x);

}


abstract interface class Logger {

  // ignore_for_file: constant_identifier_names
  //
  //  Colors
  //
  static const String GRAY    = '\x1B[90m';  // bright black
  static const String RED     = '\x1B[91m';
  static const String GREEN   = '\x1B[92m';
  static const String YELLOW  = '\x1B[93m';
  static const String BLUE    = '\x1B[94m';
  static const String MAGENTA = '\x1B[95m';
  static const String CYAN    = '\x1B[96m';
  static const String WHITE   = '\x1B[97m';
  static const String CLEAR   = '\x1B[0m';

  static String    debugColor = GRAY;     // debug
  static String   normalColor = '';       // info
  static String  warningColor = YELLOW;   // warning
  static String    fatalColor = MAGENTA;  // error
  static String    clearColor = CLEAR;

  // ignore_for_file: non_constant_identifier_names
  //
  //  Tags
  //
  static String   DEBUG_TAG = " DEBUG ";
  static String    INFO_TAG = "       ";
  static String WARNING_TAG = "WARNING";
  static String   ERROR_TAG = " ERROR ";

  LogPrinter get printer;

  void   debug(Object? msg, {String? className});
  void    info(Object? msg, {String? className});
  void warning(Object? msg, {String? className});
  void   error(Object? msg, {String? className});

  /// limit log info
  static String shorten(String text, int maxLen) {
    assert(maxLen > 128, 'too short: $maxLen');
    int size = text.length;
    if (size <= maxLen) {
      return text;
    }
    String desc = 'total $size chars';
    int pos = (maxLen - desc.length - 10) >> 1;
    if (pos <= 0) {
      return text;
    }
    String prefix = text.substring(0, pos);
    String suffix = text.substring(size - pos);
    return '$prefix ... $desc ... $suffix';
  }

}
