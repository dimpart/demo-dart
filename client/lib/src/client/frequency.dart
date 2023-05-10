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
import 'package:dimp/dimp.dart';
import 'package:object_key/object_key.dart';

///  Frequency checker for duplicated queries
class FrequencyChecker <K> {
  FrequencyChecker(double lifeSpan) : _expires = lifeSpan;

  final Map<K, double> _records = {};
  final double _expires;

  bool isExpired(K key, {double? now, bool force = false}) {
    now ??= Time.currentTimestamp;
    if (force) {
      // ignore last updated time, force to update now
    } else {
      // check last updated time
      double? expired = _records[key];
      if (expired != null && expired > now) {
        // record exists and not expired yet
        return false;
      }
    }
    _records[key] = now + _expires;
    return true;
  }
}

// each query will be expired after 10 minutes
const double expires = 600;

class QueryFrequencyChecker {
  factory QueryFrequencyChecker() => _instance;
  static final QueryFrequencyChecker _instance = QueryFrequencyChecker._internal();
  QueryFrequencyChecker._internal()
      : _metaQueries = FrequencyChecker(expires),
        _docQueries = FrequencyChecker(expires),
        _groupQueries = FrequencyChecker(expires),
        _docResponses = FrequencyChecker(expires);

  final FrequencyChecker<ID> _metaQueries;   // query for meta
  final FrequencyChecker<ID> _docQueries;    // query for document
  final FrequencyChecker<ID> _groupQueries;  // query for group members
  final FrequencyChecker<ID> _docResponses;  // response for document

  bool isMetaQueryExpired(ID identifier, {double? now}) {
    return _metaQueries.isExpired(identifier, now: now);
  }

  bool isDocumentQueryExpired(ID identifier, {double? now}) {
    return _docQueries.isExpired(identifier, now: now);
  }

  bool isMembersQueryExpired(ID identifier, {double? now}) {
    return _groupQueries.isExpired(identifier, now: now);
  }

  bool isDocumentResponseExpired(ID identifier, {double? now, bool force = false}) {
    return _docResponses.isExpired(identifier, now: now, force: force);
  }

}
