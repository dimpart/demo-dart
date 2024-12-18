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
import 'package:dimsdk/dimsdk.dart';
import 'package:object_key/object_key.dart';

import '../protocol/login.dart';


class ProviderInfo {
  ProviderInfo(this.identifier, this.chosen);

  final ID identifier;
  int chosen;

  @override
  String toString() {
    return '<$runtimeType ID="$identifier" chosen=$chosen />';
  }

  /// default service provider
  // ignore: non_constant_identifier_names
  static final ID GSP = Identifier.create(name: 'gsp', address: Address.EVERYWHERE);

  //
  //  Conveniences
  //

  static List<ProviderInfo> convert(Iterable<Map> array) {
    List<ProviderInfo> providers = [];
    ID? identifier;
    int chosen;
    for (var item in array) {
      identifier = ID.parse(item['ID']);
      chosen = Converter.getInt(item['chosen'], 0)!;
      if (identifier == null) {
        // SP ID error
        continue;
      }
      providers.add(ProviderInfo(identifier, chosen));
    }
    return providers;
  }

  static List<Map> revert(Iterable<ProviderInfo> providers) {
    List<Map> array = [];
    for (var info in providers) {
      array.add({
        'ID': info.identifier.toString(),
        'chosen': info.chosen,
      });
    }
    return array;
  }

}


class StationInfo {
  StationInfo(ID? sid, this.chosen,
      {required this.host, required this.port, required this.provider}) {
    identifier = sid ?? Station.kAny;  // 'station@anywhere'
  }

  late ID identifier;
  int chosen;

  final String host;
  final int port;

  ID? provider;

  @override
  String toString() {
    return '<$runtimeType host="$host" port=$port ID="$identifier"'
        ' SP="$provider" chosen=$chosen />';
  }

  //
  //  Conveniences
  //

  static List<StationInfo> convert(Iterable<Map> array) {
    List<StationInfo> stations = [];
    ID? sid;
    int chosen;
    String? host;
    int port;
    ID? provider;
    for (var item in array) {
      sid = ID.parse(item['ID']);
      chosen = Converter.getInt(item['chosen'], 0)!;
      host = Converter.getString(item['host'], null);
      port = Converter.getInt(item['port'], 0)!;
      provider = ID.parse(item['provider']);
      if (host == null || port == 0/* || provider == null*/) {
        // station socket error
        continue;
      }
      stations.add(StationInfo(sid, chosen, host: host, port: port, provider: provider));
    }
    return stations;
  }

  static List<Map> revert(Iterable<StationInfo> stations) {
    List<Map> array = [];
    for (var info in stations) {
      array.add({
        'ID': info.identifier.toString(),
        'chosen': info.chosen,
        'host': info.host,
        'port': info.port,
        'provider': info.provider?.toString(),
      });
    }
    return array;
  }

}


///  Session DBI
///  ~~~~~~~~~~~
abstract interface class ProviderDBI {

  ///  Get all providers
  ///
  /// @return provider list (ID, chosen)
  Future<List<ProviderInfo>> allProviders();

  ///  Add provider info
  ///
  /// @param identifier - sp ID
  /// @param chosen     - whether current sp
  /// @return false on failed
  Future<bool> addProvider(ID pid, {int chosen = 0});

  ///  Update provider info
  ///
  /// @param identifier - sp ID
  /// @param chosen     - whether current sp
  /// @return false on failed
  Future<bool> updateProvider(ID pid, {int chosen = 0});

  ///  Remove provider info
  ///
  /// @param identifier - sp ID
  /// @return false on failed
  Future<bool> removeProvider(ID pid);

}


///  Session DBI
///  ~~~~~~~~~~~
abstract interface class StationDBI {

  ///  Get all stations of this sp
  ///
  /// @param provider - sp ID (default is 'gsp@everywhere')
  /// @return station list ((host, port), sp, chosen)
  Future<List<StationInfo>> allStations({required ID provider});

  ///  Add station info with sp ID
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param provider - sp ID
  /// @param chosen   - whether current station
  /// @return false on failed
  Future<bool> addStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider});

  ///  Update station info
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param station  - station ID
  /// @param name     - station name
  /// @param chosen   - whether current station
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> updateStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider});

  ///  Remove this station
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> removeStation({required String host, required int port, required ID provider});

  ///  Remove all station of the sp
  ///
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> removeStations({required ID provider});

}


///  Session DBI
///  ~~~~~~~~~~~
abstract interface class LoginDBI {

  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier);

  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg);

}


///  Session DBI
///  ~~~~~~~~~~~
abstract interface class SessionDBI implements LoginDBI, ProviderDBI, StationDBI {

}
