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
import 'package:dimsdk/dimsdk.dart';

import '../mkm/provider.dart';
import '../mkm/station.dart';


///  Login command: {
///      type : 0x88,
///      sn   : 123,
///
///      command  : "login",
///      time     : 0,
///      //---- client info ----
///      did      : "{UserID}",
///      device   : "DeviceID",  // (optional)
///      agent    : "UserAgent", // (optional)
///      //---- server info ----
///      station  : {
///          did  : "{StationID}",
///          host : "{IP}",
///          port : 9394
///      },
///      provider : {
///          did  : "{SP_ID}"
///      }
///  }
abstract interface class LoginCommand implements Command {

  // ignore: constant_identifier_names
  static const String LOGIN = 'login';

  //
  //  Client Info
  //

  /// user ID
  ID get identifier;

  /// device ID
  String? get device;
  set device(String? v);

  /// user-agent
  String? get agent;
  set agent(String? ua);

  //
  //  Server Info
  //

  /// station info
  Map? get station;
  set station(dynamic info);

  /// service provider
  Map? get provider;
  set provider(dynamic info);

  //
  //  Factory
  //

  static LoginCommand fromID(ID identifier) => BaseLoginCommand.fromID(identifier);
}

class BaseLoginCommand extends BaseCommand implements LoginCommand{
  BaseLoginCommand(super.dict);

  BaseLoginCommand.fromID(ID identifier) : super.fromCmd(LoginCommand.LOGIN) {
    setString('did', identifier);
  }

  @override
  ID get identifier => ID.parse(this['did'])!;

  @override
  String? get device => getString('device');

  @override
  set device(String? v) => v == null ? remove('device') : this['device'] = v;

  @override
  String? get agent => getString('agent');

  @override
  set agent(String? ua) => ua == null ? remove('agent') : this['agent'] = ua;

  @override
  Map? get station => this['station'];

  @override
  set station(dynamic info) {
    if (info is Station) {
      ID sid = info.identifier;
      if (sid.isBroadcast) {
        info = {'host': info.host, 'port': info.port};
      } else {
        info = {'host': info.host, 'port': info.port, 'did': sid.toString()};
      }
      this['station'] = info;
    } else if (info is Map) {
      assert(info.containsKey('did'), 'station info error: $info');
      this['station'] = info;
    } else {
      assert(info == null, 'station info error: $info');
      remove('station');
    }
  }

  @override
  Map? get provider => this['provider'];

  @override
  set provider(dynamic info) {
    if (info is ServiceProvider) {
      this['provider'] = {'did': info.identifier.toString()};
    } else if (info is ID) {
      this['provider'] = {'did': info.toString()};
    } else if (info is Map) {
      assert(info.containsKey('did'), 'station info error: $info');
      this['provider'] = info;
    } else {
      assert(info == null, 'provider info error: $info');
      remove('provider');
    }
  }
}
