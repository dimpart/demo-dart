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

class Pair<A, B> {
  const Pair(this.first, this.second);

  final A first;
  final B second;

  @override
  bool operator ==(Object other) {
    if (other is Pair) {
      if (identical(this, other)) {
        // same object
        return true;
      }
      return Wrapper.objectEquals(first, other.first)
          && Wrapper.objectEquals(second, other.second);
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(first, second);

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz>\n\t<a>$first</a>\n\t<b>$second</b>\n</$clazz>';
  }

}

class Triplet<A, B, C> {
  const Triplet(this.first, this.second, this.third);

  final A first;
  final B second;
  final C third;

  @override
  bool operator ==(Object other) {
    if (other is Triplet) {
      if (identical(this, other)) {
        // same object
        return true;
      }
      return Wrapper.objectEquals(first, other.first)
          && Wrapper.objectEquals(second, other.second)
          && Wrapper.objectEquals(third, other.third);
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(first, second, third);

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz>\n\t<a>$first</a>\n\t<b>$second</b>\n\t<c>$third</c>\n</$clazz>';
  }

}
