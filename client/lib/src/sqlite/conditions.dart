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
import 'values.dart';

class SQLConditions {
  SQLConditions({required String left, required String comparison, required dynamic right})
      : _condition = _CompareCondition(left, comparison, right);

  _Condition _condition;

  // const
  static final SQLConditions kTrue = SQLConditions(left: '1', comparison: '<>', right: 0);
  static final SQLConditions kFalse = SQLConditions(left: '1', comparison: '=', right: 0);

  // Relation
  static const String kAnd = ' AND ';
  static const String kOr  = ' OR ';

  void appendEscapeValue(StringBuffer sb) => _condition.appendEscapeValue(sb);

  void addCondition(String relation,
      {required String left, required String comparison, required dynamic right}) {
    _Condition cond = _CompareCondition(left, comparison, right);
    _condition = _RelatedCondition(_condition, relation, cond);
  }

}

//
//  Conditions
//

abstract class _Condition {

  void appendEscapeValue(StringBuffer sb);

}

class _CompareCondition implements _Condition {
  _CompareCondition(this._left, this._op, this._right);

  final String _left;
  final String _op;
  final dynamic _right;

  @override
  void appendEscapeValue(StringBuffer sb) {
    sb.write(_left);
    sb.write(_op);
    SQLValues.appendEscapeValue(sb, _right);
  }

}

class _RelatedCondition implements _Condition {
  _RelatedCondition(this._left, this._relation, this._right);

  final _Condition _left;
  final String _relation;
  final _Condition _right;

  static void _appendEscapeValue(StringBuffer sb, _Condition cond) {
    if (cond is _RelatedCondition) {
      sb.write('(');
      cond.appendEscapeValue(sb);
      sb.write(')');
    } else {
      cond.appendEscapeValue(sb);
    }
  }

  @override
  void appendEscapeValue(StringBuffer sb) {
    _appendEscapeValue(sb, _left);
    assert(_relation == SQLConditions.kAnd
        || _relation == SQLConditions.kOr, 'relation error: $_relation');
    sb.write(_relation);
    _appendEscapeValue(sb, _right);
  }

}
