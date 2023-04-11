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

import '../protocol/login.dart';
import '../utils/tuples.dart';


///  Session DBI
///  ~~~~~~~~~~~
abstract class LoginDBI {

  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier);

  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg);

}


///  Session DBI
///  ~~~~~~~~~~~
abstract class ProviderDBI {

  ///  get all neighbor stations
  ///
  /// @return a set of (host, port, ID)
  Future<Set<Triplet<String, int, ID?>>> allNeighbors();

  Future<ID?> getNeighbor(String host, int port);

  Future<bool> addNeighbor(String host, int port, [ID? station]);

  Future<bool> removeNeighbor(String host, int port);
}


///  Session DBI
///  ~~~~~~~~~~~
abstract class SessionDBI implements LoginDBI, ProviderDBI {

}
