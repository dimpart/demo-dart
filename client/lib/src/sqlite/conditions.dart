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


// ignore_for_file: non_constant_identifier_names
abstract interface class SQLConditions {

  // const
  static final Predicate TRUE  = SinglePredicate('1=1');
  static final Predicate FALSE = SinglePredicate('1=0');

  // creator
  static Predicate create(String name, String op, dynamic value) =>
      ComparePredicate(name, op, value);

}


class SinglePredicate extends Predicate {
  SinglePredicate(this.expression);

  final String expression;

  @override
  void appendPredicate(StringBuffer sb) {
    sb.write(expression);
  }
}


class ComparePredicate extends Predicate {
  ComparePredicate(this.name, this.operator, this.value);

  final String name;
  final String operator;
  final dynamic value;

  @override
  void appendPredicate(StringBuffer sb) {
    sb.write(name);
    sb.write(operator);
    SQLValues.appendEscapeValue(sb, value);
  }

}


// ignore_for_file: constant_identifier_names
abstract interface class Comparisons {

  static const String EQ = '=';   // Equal
  static const String NE = '<>';  // Not Equal

  static const String LT = '<';   // Less Than
  static const String LE = '<=';  // Less than or Equal to

  static const String GT = '>';   // Greater than
  static const String GE = '>=';  // Greater than or Equal to

}
