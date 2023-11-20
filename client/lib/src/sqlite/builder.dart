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
import 'conditions.dart';
import 'values.dart';

class SQLBuilder {
  SQLBuilder(String command) : _sb = StringBuffer(command);

  final StringBuffer _sb;

  static const String create = "CREATE";
  static const String alter  = "ALTER";

  static const String insert = "INSERT";
  static const String select = "SELECT";
  static const String update = "UPDATE";
  static const String delete = "DELETE";

  @override
  String toString() => _sb.toString();

  void _append(String sub) {
    _sb.write(sub);
  }
  void _appendStringList(List<String> array) {
    SQLValues.appendStringList(_sb, array);
  }
  void _appendEscapeValueList(List array) {
    SQLValues.appendEscapeValueList(_sb, array);
  }
  void _appendValues(SQLValues values) {
    values.appendValues(_sb);
  }

  //  SELECT *       ...
  //  SELECT columns ...
  void _appendColumns(List<String> columns) {
    if (columns.isEmpty) {
      _append(' *');
    } else {
      _append(' ');
      _appendStringList(columns);
    }
  }
  void _appendClause(String name, String? clause) {
    if (clause == null || clause.isEmpty) {
      return;
    }
    _append(name);
    _append(clause);
  }
  void _appendWhere(SQLConditions? conditions) {
    if (conditions == null) {
      return;
    }
    _append(' WHERE ');
    conditions.appendEscapeValue(_sb);
  }

  ///
  ///  CREATE TABLE IF NOT EXISTS table (field type, ...);
  ///
  static String buildCreateTable(String table, {required List<String> fields}) {
    SQLBuilder builder = SQLBuilder(create);
    builder._append(' TABLE IF NOT EXISTS ');
    builder._append(table);
    builder._append('(');
    builder._appendStringList(fields);
    builder._append(')');
    return builder.toString();
  }

  ///
  ///  CREATE INDEX IF NOT EXISTS name ON table (fields);
  ///
  static String buildCreateIndex(String table,
      {required String name, required List<String> fields}) {
    SQLBuilder builder = SQLBuilder(create);
    builder._append(' INDEX IF NOT EXISTS ');
    builder._append(name);
    builder._append(' ON ');
    builder._append(table);
    builder._append('(');
    builder._appendStringList(fields);
    builder._append(')');
    return builder.toString();
  }

  ///
  ///  ALTER TABLE table ADD COLUMN IF NOT EXISTS name type;
  ///
  static String buildAddColumn(String table,
      {required String name, required String type}) {
    SQLBuilder builder = SQLBuilder(alter);
    builder._append(' TABLE ');
    builder._append(table);
    // builder._append(' ADD COLUMN IF NOT EXISTS ');
    builder._append(' ADD COLUMN ');
    builder._append(name);
    builder._append(' ');
    builder._append(type);
    return builder.toString();
  }

  //
  //  DROP TABLE IF EXISTS table;
  //

  ///
  ///  INSERT INTO table (columns) VALUES (values);
  ///
  static String buildInsert(String table,
      {required List<String> columns, required List values}) {
    SQLBuilder builder = SQLBuilder(insert);
    builder._append(' INTO ');
    builder._append(table);
    builder._append('(');
    builder._appendStringList(columns);
    builder._append(') VALUES (');
    builder._appendEscapeValueList(values);
    builder._append(')');
    return builder.toString();
  }

  ///
  ///  SELECT DISTINCT columns FROM tables WHERE conditions
  ///          GROUP BY ...
  ///          HAVING ...
  ///          ORDER BY ...
  ///          LIMIT count OFFSET start;
  ///
  static String buildSelect(String table,
      {bool distinct = false,
        required List<String> columns, required SQLConditions conditions,
        String? groupBy, String? having, String? orderBy,
        int offset = 0, int? limit}) {
    SQLBuilder builder = SQLBuilder(select);
    if (distinct) {
      builder._append(' DISTINCT');
    }
    builder._appendColumns(columns);
    builder._append(' FROM ');
    builder._append(table);
    builder._appendWhere(conditions);
    builder._appendClause(' GROUP BY ', groupBy);
    builder._appendClause(' HAVING ', having);
    builder._appendClause(' ORDER BY ', orderBy);
    if (limit != null) {
      builder._append(' LIMIT $limit OFFSET $offset');
    }
    return builder.toString();
  }

  ///
  ///  UPDATE table SET name=value WHERE conditions
  ///
  static String buildUpdate(String table,
      {required Map<String, dynamic> values, required SQLConditions conditions}) {
    SQLBuilder builder = SQLBuilder(update);
    builder._append(' ');
    builder._append(table);
    builder._append(' SET ');
    builder._appendValues(SQLValues.from(values));
    builder._appendWhere(conditions);
    return builder.toString();
  }

  ///
  ///  DELETE FROM table WHERE conditions
  ///
  static String buildDelete(String table, {required SQLConditions conditions}) {
    SQLBuilder builder = SQLBuilder(delete);
    builder._append(' FROM ');
    builder._append(table);
    builder._appendWhere(conditions);
    return builder.toString();
  }

}
