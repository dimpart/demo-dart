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

abstract class ResultSet {

  /// Moves the cursor forward one row from its current position.
  /// A <code>ResultSet</code> cursor is initially positioned
  /// before the first row; the first call to the method
  /// <code>next</code> makes the first row the current row; the
  /// second call makes the second row the current row, and so on.
  /// <p>
  /// When a call to the <code>next</code> method returns <code>false</code>,
  /// the cursor is positioned after the last row. Any
  /// invocation of a <code>ResultSet</code> method which requires a
  /// current row will result in a <code>Exception</code> being thrown.
  ///  If the result set type is <code>TYPE_FORWARD_ONLY</code>, it is vendor specified
  /// whether their JDBC driver implementation will return <code>false</code> or
  ///  throw an <code>SQLException</code> on a
  /// subsequent call to <code>next</code>.
  ///
  /// <P>If an input stream is open for the current row, a call
  /// to the method <code>next</code> will
  /// implicitly close it. A <code>ResultSet</code> object's
  /// warning chain is cleared when a new row is read.
  ///
  /// @return <code>true</code> if the new current row is valid;
  /// <code>false</code> if there are no more rows
  /// @exception SQLException if a database access error occurs or this method is
  ///            called on a closed result set
  bool next();


  /// Retrieves the current row number.  The first row is number 1, the
  /// second number 2, and so on.
  /// <p>
  /// <strong>Note:</strong>Support for the <code>getRow</code> method
  /// is optional for <code>ResultSet</code>s with a result
  /// set type of <code>TYPE_FORWARD_ONLY</code>
  ///
  /// @return the current row number; <code>0</code> if there is no current row
  /// @exception SQLException if a database access error occurs
  /// or this method is called on a closed result set
  /// @exception SQLFeatureNotSupportedException if the JDBC driver does not support
  /// this method
  /// @since 1.2
  int get row;

  dynamic getValue(String columnLabel);

  String getString(String columnLabel) => getValue(columnLabel);

  int getInt(String columnLabel) => getValue(columnLabel);

  double getDouble(String columnLabel) => getValue(columnLabel);

  void close();

}

abstract class Statement {

  /// 'INSERT INTO t_user(id, name) VALUES("moky@anywhere", "Moky")'
  Future<int> executeInsert(String sql);

  /// 'SELECT id, name FROM t_user'
  Future<ResultSet> executeQuery(String sql);

  /// 'UPDATE t_user SET name = "Albert Moky" WHERE id = "moky@anywhere"'
  Future<int> executeUpdate(String sql);

  /// 'DELETE FROM t_user WHERE id = "moky@anywhere"'
  Future<int> executeDelete(String sql);

  void close();

}

abstract class DBConnection {

  Statement createStatement();

  void close();

}

/// DataRowExtractor<T>
typedef OnExtractDataRow<T> = T Function(ResultSet resultSet, int index);
