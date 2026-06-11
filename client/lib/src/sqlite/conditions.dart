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
import 'predicate.dart';
import 'values.dart';


/// Search Condition
class SQLConditions {
  SQLConditions(this.predicate);

  Predicate predicate;

  /// Append predicate string to the buffer
  void appendConditionString(StringBuffer sb) =>
      predicate.appendPredicateString(sb);

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    appendConditionString(sb);
    return sb.toString();
  }

  /// Create new condition: "{this_cond} AND {other_cond}"
  SQLConditions and(SQLConditions other) {
    // this condition
    Predicate thisCond = predicate;
    if (thisCond is CompoundPredicate) {
      if (thisCond.relation != Relation.AND) {
        assert(thisCond.relation == Relation.OR, 'compound predicate error: $thisCond');
        thisCond = thisCond.enclose();
      }
    } else if (thisCond is InversePredicate) {
      thisCond = thisCond.enclose();
    }
    // other condition
    Predicate otherCond = other.predicate;
    if (otherCond is CompoundPredicate) {
      if (otherCond.relation != Relation.AND) {
        assert(otherCond.relation == Relation.OR, 'compound predicate error: $otherCond');
        otherCond = otherCond.enclose();
      }
    } else if (otherCond is InversePredicate) {
      otherCond = otherCond.enclose();
    }
    // OK
    return SQLConditions(thisCond.and(otherCond));
  }

  /// Create new condition: "{this_cond} OR {other_cond}"
  SQLConditions or(SQLConditions other) {
    // this condition
    Predicate thisCond = predicate;
    if (thisCond is CompoundPredicate) {
      if (thisCond.relation != Relation.OR) {
        assert(thisCond.relation == Relation.AND, 'compound predicate error: $thisCond');
        thisCond = thisCond.enclose();
      }
    } else if (thisCond is InversePredicate) {
      thisCond = thisCond.enclose();
    }
    // other condition
    Predicate otherCond = other.predicate;
    if (otherCond is CompoundPredicate) {
      if (otherCond.relation != Relation.OR) {
        assert(otherCond.relation == Relation.AND, 'compound predicate error: $otherCond');
        otherCond = otherCond.enclose();
      }
    } else if (otherCond is InversePredicate) {
      otherCond = otherCond.enclose();
    }
    // OK
    return SQLConditions(thisCond.or(otherCond));
  }

  /// Create new condition: "NOT {this_cond}"
  SQLConditions not() {
    Predicate cond = predicate;
    if (cond is InversePredicate) {
      cond = cond.predicate;
    } else {
      cond = InversePredicate(cond);
    }
    // OK
    return SQLConditions(cond);
  }

  //
  //  conveniences
  //

  SQLConditions andCompare(String name, String op, dynamic value) =>
      and(compare(name, op, value));

  SQLConditions orCompare(String name, String op, dynamic value) =>
      or(compare(name, op, value));

  //
  //  constants
  //

  static final SQLConditions TRUE  = simple('1=1');
  static final SQLConditions FALSE = simple('1=0');
  // ignore_for_file: non_constant_identifier_names

  //
  //  factory methods
  //

  static SQLConditions simple(String expression) =>
      SQLConditions(SimplePredicate(expression));

  static SQLConditions compare(String name, String op, dynamic value) =>
      SQLConditions(ComparePredicate(name, op, value));

}


class SimplePredicate extends Predicate {
  SimplePredicate(this.expression);

  final String expression;

  @override
  void appendPredicateString(StringBuffer sb) {
    sb.write(expression);
  }

}


class ComparePredicate extends Predicate {
  ComparePredicate(this.name, this.operator, this.value);

  final String name;
  final String operator;
  final dynamic value;

  @override
  void appendPredicateString(StringBuffer sb) {
    sb.write(name);
    sb.write(operator);
    SQLValues.appendEscapeValue(sb, value);
  }

}

// abstract interface class Comparisons {
//
//   static const String EQ = '=';   // Equal
//   static const String NE = '<>';  // Not Equal
//
//   static const String LT = '<';   // Less Than
//   static const String LE = '<=';  // Less than or Equal to
//
//   static const String GT = '>';   // Greater than
//   static const String GE = '>=';  // Greater than or Equal to
//
// }
