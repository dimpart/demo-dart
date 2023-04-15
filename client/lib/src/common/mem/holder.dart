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
import '../../dim_utils.dart';

class CacheHolder <V> {
  CacheHolder(V? cacheValue, int cacheLifeSpan, {int? now})
      : _value = cacheValue, _life = cacheLifeSpan {
    now ??= Time.currentTimeMillis;
    _expired = now + cacheLifeSpan;
    _deprecated = now + (cacheLifeSpan << 1);
  }

  V? _value;

  final int _life;      // life span
  int _expired = 0;     // time to expired
  int _deprecated = 0;  // time to deprecated

  V? get value => _value;

  void update(V? newValue, {int? now}) {
    _value = newValue;
    now ??= Time.currentTimeMillis;
    _expired = now + _life;
    _deprecated = now + (_life << 1);
  }

  bool isAlive({int? now}) {
    now ??= Time.currentTimeMillis;
    return now < _expired;
  }

  bool isDeprecated({int? now}) {
    now ??= Time.currentTimeMillis;
    return now > _deprecated;
  }

  void renewal({int? duration, int? now}) {
    duration ??= 120 * 1000;
    now ??= Time.currentTimeMillis;
    _expired = now + duration;
    _deprecated = now + (_life << 1);
  }

}

class CachePair <V> {
  CachePair(this.value, this.holder);

  final V? value;
  final CacheHolder<V> holder;

}
