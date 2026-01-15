/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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


abstract interface class MemoryCache<K, V> {

  V? get(K key);

  void put(K key, V? value);

  int reduceMemory();

}


class ThanosCache<K, V> implements MemoryCache<K, V> {

  final Map<K, V> _caches = {};

  @override
  V? get(K key) => _caches[key];

  @override
  void put(K key, V? value) => value == null
      ? _caches.remove(key)
      : _caches[key] = value;

  @override
  int reduceMemory() {
    int finger = 0;
    finger = thanos(_caches, finger);
    return finger >> 1;
  }

}


/// Thanos
/// ~~~~~~
/// Thanos can kill half lives of a world with a snap of the finger
int thanos(Map planet, int finger) {
  // if ++finger is odd, remove it,
  // else, let it go
  planet.removeWhere((key, value) => (++finger & 1) == 1);
  return finger;
}
