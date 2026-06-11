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


/// Predicates Relation
class Relation {
  Relation(this._op);

  final String _op;

  void appendRelationString(StringBuffer sb) => sb.write(_op);

  @override
  String toString() => _op;

  // ignore_for_file: non_constant_identifier_names
  static final Relation AND = Relation('AND');
  static final Relation OR  = Relation('OR');
  static final Relation NOT = Relation('NOT');

}


/// Search Condition
abstract class Predicate {

  /// Append to the buffer (with escaped value)
  void appendPredicateString(StringBuffer sb);

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    appendPredicateString(sb);
    return sb.toString();
  }

  /// Create new predicate: "{this} AND {other}"
  Predicate and(Predicate other) => CompoundPredicate(this, Relation.AND, other);

  /// Create new predicate: "{this} OR {other}"
  Predicate or(Predicate other) => CompoundPredicate(this, Relation.OR, other);

  /// Create new predicate: "NOT {this}"
  Predicate not() => InversePredicate(this);

  /// Create new predicate: "({this})"
  Predicate enclose() => EnclosedPredicate(this);

}


/// Compound Predicate
///
///     {left_predicate} AND {right_predicate}
///     {left_predicate} OR {right_predicate}
class CompoundPredicate extends Predicate {
  CompoundPredicate(this.left, this.relation, this.right);

  final Predicate left;
  final Relation relation;
  final Predicate right;

  @override
  void appendPredicateString(StringBuffer sb) {
    left.appendPredicateString(sb);
    sb.write(' ');
    relation.appendRelationString(sb);
    sb.write(' ');
    right.appendPredicateString(sb);
  }

}


/// Inverse Predicate
///
///     NOT {predicate}
class InversePredicate extends Predicate {
  InversePredicate(this.predicate);

  final Predicate predicate;

  @override
  void appendPredicateString(StringBuffer sb) {
    var child = predicate;
    if (child is InversePredicate) {
      assert(false, 'double negative: "$child"');
      // reverse sub predicate
      child.predicate.appendPredicateString(sb);
    } else if (child is CompoundPredicate) {
      // 1. "NOT ({predicate} AND {predicate})"
      // 2. "NOT ({predicate} OR {predicate})"
      Relation.NOT.appendRelationString(sb);
      sb.write(' (');
      child.appendPredicateString(sb);
      sb.write(')');
    // } else if (child is EnclosedPredicate) {
    //   // 3. "NOT ({predicate})"
    //   Relation.NOT.appendRelationString(sb);
    //   sb.write(' ');
    //   child.appendPredicateString(sb);
    } else {
      // 3. "NOT {predicate}"
      Relation.NOT.appendRelationString(sb);
      sb.write(' ');
      child.appendPredicateString(sb);
    }
  }

}


class EnclosedPredicate extends Predicate {
  EnclosedPredicate(this.predicate);

  final Predicate predicate;

  @override
  void appendPredicateString(StringBuffer sb) {
    if (predicate is EnclosedPredicate) {
      assert(false, 'duplicated brackets: "$predicate"');
      // no need to add more brackets
      predicate.appendPredicateString(sb);
    } else {
      sb.write('(');
      predicate.appendPredicateString(sb);
      sb.write(')');
    }
  }

}
