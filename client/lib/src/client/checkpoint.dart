/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
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
import 'package:dimp/dkd.dart';


/// Signature pool for messages
class SigPool {

  static int kExpires = 3600 * 1000;

  final Map<String, int> _caches = {};  // signature:receiver => timestamp
  int _nextTime = 0;

  /// Remove expired traces
  bool purge(DateTime now) {
    if (now.millisecondsSinceEpoch < _nextTime) {
      return false;
    }
    now = DateTime.now();
    int timestamp = now.millisecondsSinceEpoch;
    if (timestamp < _nextTime) {
      return false;
    } else {
      // purge it next 5 minutes
      _nextTime = timestamp + 300 * 1000;
    }
    int expired = timestamp - kExpires;
    _caches.removeWhere((key, value) => value < expired);
    return true;
  }

  /// Check whether duplicated
  bool duplicated(ReliableMessage msg) {
    String? sig = msg.getString('signature', null);
    if (sig == null) {
      assert(false, 'message error: $msg');
      return true;
    } else {
      sig = getSig(sig, 16);
    }
    String address = msg.receiver.address.toString();
    String tag = '$sig:$address';
    if (_caches.containsKey(tag)) {
      return true;
    }
    // cache not found, create a new one with message time
    DateTime? when = msg.time;
    when ??= DateTime.now();
    _caches[tag] = when.millisecondsSinceEpoch;
    return false;
  }

  static String? getSig(String? signature, int maxLen) {
    assert(maxLen > 0);
    int len = signature?.length ?? 0;
    return len <= maxLen ? signature : signature?.substring(len - maxLen);
  }

}


/// Check for duplicate messages
class Checkpoint {
  factory Checkpoint() => _instance;
  static final Checkpoint _instance = Checkpoint._internal();
  Checkpoint._internal();

  final SigPool _pool = SigPool();

  bool duplicated(ReliableMessage msg) {
    bool repeated = _pool.duplicated(msg);
    DateTime? now = msg.time;
    if (now != null) {
      _pool.purge(now);
    }
    return repeated;
  }

  String? getSig(ReliableMessage msg) {
    String? sig = msg.getString('signature', null);
    return SigPool.getSig(sig, 8);
  }

}
