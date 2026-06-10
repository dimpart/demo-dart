/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2026 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2026 Albert Moky
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


// ignore_for_file: constant_identifier_names
abstract interface class Relations {

  static const String AND = 'AND';
  static const String OR  = 'OR';
  static const String NOT = 'NOT';

}


/// SQL Condition
abstract class Predicate {

  /// Append to the buffer (with escaped value)
  void appendPredicate(StringBuffer sb);

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    appendPredicate(sb);
    return sb.toString();
  }

  Predicate and(Predicate other) => CompoundPredicate(this, Relations.AND, other);

  Predicate or(Predicate other) => CompoundPredicate(this, Relations.OR, other);

  // Predicate not();  // TODO:

}


class CompoundPredicate extends Predicate {
  CompoundPredicate(this.left, this.relation, this.right);

  final Predicate left;
  final String relation;
  final Predicate right;

  @override
  void appendPredicate(StringBuffer sb) {
    // append left
    if (left is CompoundPredicate) {
      sb.write('(');
      left.appendPredicate(sb);
      sb.write(') ');
    } else {
      left.appendPredicate(sb);
      sb.write(' ');
    }

    // append middle
    sb.write(relation);

    // append right
    if (right is CompoundPredicate) {
      sb.write(' (');
      right.appendPredicate(sb);
      sb.write(')');
    } else {
      sb.write(' ');
      right.appendPredicate(sb);
    }
  }

}
