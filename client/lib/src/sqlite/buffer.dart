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
import 'predicate.dart';
import 'values.dart';


class SQLStringBuffer {
  SQLStringBuffer(String command) : _sb = StringBuffer(command);

  final StringBuffer _sb;

  @override
  String toString() => _sb.toString();

  // protected
  SQLStringBuffer appendString(String sub) {
    _sb.write(sub);
    return this;
  }

  // protected
  SQLStringBuffer appendStringList(List<String> array) {
    SQLValues.appendStringList(_sb, array);
    return this;
  }

  // protected
  SQLStringBuffer appendEscapeValueList(List array) {
    SQLValues.appendEscapeValueList(_sb, array);
    return this;
  }

  // protected
  SQLStringBuffer appendValues(SQLValues values) {
    values.appendValues(_sb);
    return this;
  }

  // protected
  SQLStringBuffer appendConditions(Predicate conditions) {
    conditions.appendPredicate(_sb);
    return this;
  }

  ///
  ///  Clauses
  ///

  // // protected
  // SQLStringBuffer appendOnTableColumns(String table, List<String> columns) =>
  //     appendString(' ON ').appendString(table)
  //         .appendString(' (').appendStringList(columns).appendString(')');
  //
  // // protected
  // SQLStringBuffer appendIntoTableColumns(String table, List<String> columns) =>
  //     appendString(' INTO ').appendString(table)
  //         .appendString(' (').appendStringList(columns).appendString(')');
  //
  // // protected
  // SQLStringBuffer appendAddColumn(String name, String type) =>
  //     // appendString(' ADD COLUMN IF NOT EXISTS ')
  //     appendString(' ADD COLUMN ')
  //         .appendString(name).appendString(' ').appendString(type);
  //
  // // protected
  // SQLStringBuffer appendFromClause(String table) =>
  //     appendString(' FROM ').appendString(table);
  //
  // // protected
  // SQLStringBuffer appendSetValues(Map<String, dynamic> values) =>
  //     appendString(' SET ').appendValues(SQLValues.from(values));

  // protected
  SQLStringBuffer appendWhereClause(Predicate? conditions, {
    String? groupBy, String? having, String? orderBy,
    int? limit, int offset = 0,
  }) {
    if (conditions != null) {
      appendString(' WHERE ').appendConditions(conditions);
    }
    if (groupBy != null) {
      assert(groupBy.isNotEmpty, 'group by empty');
      appendString(' GROUP BY ').appendString(groupBy);
    }
    if (having != null) {
      assert(having.isNotEmpty, 'having empty');
      appendString(' HAVING ').appendString(having);
    }
    if (orderBy != null) {
      assert(orderBy.isNotEmpty, 'order by empty');
      appendString(' ORDER BY ').appendString(orderBy);
    }
    if (limit != null) {
      assert(limit > 0, 'limit error');
      appendString(' LIMIT $limit OFFSET $offset');
    }
    return this;
  }

}
