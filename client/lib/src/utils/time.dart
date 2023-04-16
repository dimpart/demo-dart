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


class Time {

  static int get currentTimeMillis => DateTime.now().millisecondsSinceEpoch;

  /// readable time string
  static String getTimeString(DateTime time) {
    time = time.toLocal();
    int timestamp = time.millisecondsSinceEpoch;
    int midnight = DateTime(time.year, time.month, time.day).millisecondsSinceEpoch;
    String hh = _twoDigits(time.hour);
    String mm = _twoDigits(time.minute);
    if (timestamp >= midnight) {
      // today
      if (time.hour < 12) {
        return 'AM $hh:$mm';
      } else {
        return 'PM $hh:$mm';
      }
    } else if (timestamp >= (midnight - 24 * 3600 * 1000)) {
      // yesterday
      return 'Yesterday $hh:$mm';
    } else if (timestamp >= (midnight - 72 * 3600 * 1000)) {
      // recently
      String weekday = _weakDayName(time.weekday);
      return '$weekday $hh:$mm';
    }
    int newYear = DateTime(time.year).millisecondsSinceEpoch;
    String m = _twoDigits(time.month);
    String d = _twoDigits(time.day);
    if (timestamp >= newYear) {
      // this year
      return '$m-$d $hh:$mm';
    } else {
      return '${time.year}-$m-$d';
    }
  }

  /// yyyy-MM-dd HH:mm:ss
  static String getFullTimeString(DateTime time) {
    time = time.toLocal();
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

  static String _weakDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        assert(false, 'weekday error: $weekday');
        return '';
    }
  }
}
