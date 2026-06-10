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
import 'buffer.dart';


// ignore_for_file: constant_identifier_names
class SQLBuilder extends SQLStringBuffer {
  SQLBuilder(super.command);

  static const String CREATE = "CREATE";
  static const String ALTER  = "ALTER";
  static const String DROP   = "DROP";

  static const String INSERT = "INSERT";
  static const String SELECT = "SELECT";
  static const String UPDATE = "UPDATE";
  static const String DELETE = "DELETE";

  ///
  ///  CREATE TABLE IF NOT EXISTS table (field type, ...);
  ///
  static String buildCreateTable(String table, {required List<String> fields}) {
    SQLBuilder builder = SQLBuilder(CREATE);
    builder.appendString(' TABLE IF NOT EXISTS ').appendString(table);
    builder.appendString(' (').appendStringList(fields).appendString(')');
    return builder.toString();
  }

  ///
  ///  CREATE INDEX IF NOT EXISTS name ON table (columns);
  ///
  static String buildCreateIndex(String table, {bool unique = false,
    required String name, required List<String> columns,
  }) {
    SQLBuilder builder = SQLBuilder(CREATE);
    if (unique) {
      builder.appendString(' UNIQUE INDEX IF NOT EXISTS ').appendString(name);
    } else {
      builder.appendString(' INDEX IF NOT EXISTS ').appendString(name);
    }
    builder.appendString(' ON ').appendString(table);
    builder.appendString(' (').appendStringList(columns).appendString(')');
    return builder.toString();
  }

  ///
  ///  ALTER TABLE old_table RENAME TO new_table;
  ///
  static String buildRenameTable(String table, {required String fromTable}) {
    SQLBuilder builder = SQLBuilder(ALTER);
    builder.appendString(' TABLE ').appendString(fromTable);
    builder.appendString(' RENAME TO ').appendString(table);
    return builder.toString();
  }

  ///
  ///  DROP TABLE IF EXISTS table;
  ///
  static String buildDropTable(String table) {
    SQLBuilder builder = SQLBuilder(DROP);
    builder.appendString(' TABLE IF EXISTS ').appendString(table);
    return builder.toString();
  }

  ///
  ///  ALTER TABLE table ADD COLUMN IF NOT EXISTS name type;
  ///
  static String buildAddColumn(String table, {
    required String name, required String type,
  }) {
    SQLBuilder builder = SQLBuilder(ALTER);
    builder.appendString(' TABLE ').appendString(table);
    // builder.appendString(' ADD COLUMN IF NOT EXISTS ');
    builder.appendString(' ADD COLUMN ');
    builder.appendString(name).appendString(' ').appendString(type);
    return builder.toString();
  }

  ///
  ///  INSERT INTO table (columns) VALUES (values);
  ///  INSERT INTO table (columns) SELECT old_columns FROM old_table ...;
  ///
  static String buildInsert(String table, {required List<String> columns,
    List? values,
    String? selectClause,
  }) {
    SQLBuilder builder = SQLBuilder(INSERT);
    builder.appendString(' INTO ').appendString(table);
    builder.appendString(' (').appendStringList(columns).appendString(')');
    if (values != null) {
      builder.appendString(' VALUES (');
      builder.appendEscapeValueList(values);
      builder.appendString(')');
    } else if (selectClause != null) {
      builder.appendString(' ');
      builder.appendString(selectClause);
    } else {
      assert(false, 'SQL error: ${builder.toString()}');
    }
    return builder.toString();
  }

  ///
  ///  SELECT DISTINCT columns FROM tables WHERE conditions
  ///          GROUP BY ...
  ///          HAVING ...
  ///          ORDER BY ...
  ///          LIMIT count OFFSET start;
  ///
  static String buildSelect(String table, {bool distinct = false,
    required List<String> columns,
    Predicate? conditions,
    String? groupBy, String? having, String? orderBy,
    int? limit, int offset = 0,
  }) {
    SQLBuilder builder = SQLBuilder(SELECT);
    if (distinct) {
      builder.appendString(' DISTINCT');
    }
    if (columns.isEmpty) {
      builder.appendString(' *');
    } else {
      builder.appendString(' ').appendStringList(columns);
    }
    builder.appendString(' FROM ').appendString(table);
    // WHERE ...
    builder.appendWhereClause(conditions,
      groupBy: groupBy, having: having, orderBy: orderBy,
      limit: limit, offset: offset,
    );
    return builder.toString();
  }

  ///
  ///  UPDATE table SET name=value WHERE conditions
  ///
  static String buildUpdate(String table, {
    required Map<String, dynamic> values,
    Predicate? conditions,
  }) {
    SQLBuilder builder = SQLBuilder(UPDATE);
    builder.appendString(' ').appendString(table);
    builder.appendString(' SET ').appendValues(SQLValues.from(values));
    // WHERE ...
    builder.appendWhereClause(conditions);
    return builder.toString();
  }

  ///
  ///  DELETE FROM table WHERE conditions
  ///
  static String buildDelete(String table, {
    Predicate? conditions
  }) {
    SQLBuilder builder = SQLBuilder(DELETE);
    builder.appendString(' FROM ').appendString(table);
    // WHERE ...
    builder.appendWhereClause(conditions);
    return builder.toString();
  }

}
