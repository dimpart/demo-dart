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

  /// default service provider
  static final ID kGSP = Identifier('gsp@everywhere', name: 'gsp', address: Address.kEverywhere);

  ///  Get all providers
  ///
  /// @return provider list (ID, chosen)
  Future<List<Pair<ID, int>>> getProviders();

  ///  Add provider info
  ///
  /// @param identifier - sp ID
  /// @param chosen     - whether current sp
  /// @return false on failed
  Future<bool> addProvider(ID identifier, {int chosen = 0});

  ///  Update provider info
  ///
  /// @param identifier - sp ID
  /// @param chosen     - whether current sp
  /// @return false on failed
  Future<bool> updateProvider(ID identifier, {int chosen = 0});

  ///  Remove provider info
  ///
  /// @param identifier - sp ID
  /// @return false on failed
  Future<bool> removeProvider(ID identifier);

}


///  Session DBI
///  ~~~~~~~~~~~
abstract class StationDBI {

  ///  Get all stations of this sp
  ///
  /// @param provider - sp ID (default is 'gsp@everywhere')
  /// @return station list (host, port)
  Future<List<Pair<String, int>>> getStations({ID provider});

  ///  Add station info with sp ID
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param provider - sp ID
  /// @param chosen   - whether current station
  /// @return false on failed
  Future<bool> addStation(String host, int port, {ID provider, int chosen = 0});

  ///  Update station info
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param station  - station ID
  /// @param name     - station name
  /// @param chosen   - whether current station
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> updateStation(String host, int port, {ID provider, int chosen});

  ///  Set this station as current station
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> chooseStation(String host, int port, {ID provider});

  ///  Remove this station
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> removeStation(String host, int port, {ID provider});

  ///  Remove all station of the sp
  ///
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> removeStations({ID provider});

}


///  Session DBI
///  ~~~~~~~~~~~
abstract class SessionDBI implements LoginDBI, ProviderDBI, StationDBI {

}
