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


///  Frequency checker for duplicated queries
class FrequencyChecker <K> {
  FrequencyChecker(Duration lifeSpan) : _expires = lifeSpan;

  final Map<K, DateTime> _records = {};
  final Duration _expires;

  bool _checkExpired(K key, DateTime now) {
    DateTime? expired = _records[key];
    if (expired != null && expired.isAfter(now)) {
      // record exists and not expired yet
      return false;
    }
    _records[key] = now.add(_expires);
    return true;
  }

  bool _forceExpired(K key, DateTime now) {
    _records[key] = now.add(_expires);
    return true;
  }
  bool isExpired(K key, {DateTime? now, bool force = false}) {
    now ??= DateTime.now();
    // if force == true:
    //     ignore last updated time, force to update now
    // else:
    //     check last update time
    if (force) {
      return _forceExpired(key, now);
    } else {
      return _checkExpired(key, now);
    }
  }

}


/// Recent time checker for querying
class RecentTimeChecker <K> {

  final Map<K, DateTime> _times = {};

  bool setLastTime(K key, DateTime? now) {
    if (now == null) {
      assert(false, 'recent time empty: $key');
      return false;
    }
    // TODO: calibration clock

    DateTime? last = _times[key];
    if (last == null || last.isBefore(now)) {
      _times[key] = now;
      return true;
    }
    return false;
  }

  bool isExpired(K key, DateTime? now) {
    if (now == null) {
      // assert(false, 'recent time empty: $key');
      return true;
    }
    DateTime? last = _times[key];
    return last != null && last.isAfter(now);
  }

}
