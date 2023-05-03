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


///  Command message: {
///      type : 0x88,
///      sn   : 123,
///
///      command  : "login",
///      time     : 0,
///      //---- client info ----
///      ID       : "{UserID}",
///      device   : "DeviceID",  // (optional)
///      agent    : "UserAgent", // (optional)
///      //---- server info ----
///      station  : {
///          ID   : "{StationID}",
///          host : "{IP}",
///          port : 9394
///      },
///      provider : {
///          ID   : "{SP_ID}"
///      }
///  }
class LoginCommand extends BaseCommand {
  LoginCommand(super.dict);

  static const String kLogin = 'login';

  LoginCommand.fromID(ID identifier) : super.fromName(kLogin) {
    setString('ID', identifier);
  }

  //
  //  Client Info
  //

  /// user ID
  ID get identifier => ID.parse(this['ID'])!;

  /// device ID
  String? get device => getString('device');
  set device(String? v) => v == null ? remove('device') : this['device'] = v;

  /// user-agent
  String? get agent => getString('agent');
  set agent(String? ua) => ua == null ? remove('agent') : this['agent'] = ua;

  //
  //  Server Info
  //

  /// station info
  Map? get station => this['station'];
  set station(dynamic info) {
    if (info is Station) {
      ID sid = info.identifier;
      if (sid.isBroadcast) {
        info = {'host': info.host, 'port': info.port};
      } else {
        info = {'host': info.host, 'port': info.port, 'ID': sid.toString()};
      }
      this['station'] = info;
    } else if (info is Map) {
      assert(info.containsKey('ID'), 'station info error: $info');
      this['station'] = info;
    } else {
      assert(info == null, 'station info error: $info');
      remove('station');
    }
  }

  /// service provider
  Map? get provider => this['provider'];
  set provider(dynamic info) {
    if (info is ServiceProvider) {
      this['provider'] = {'ID': info.identifier.toString()};
    } else if (info is ID) {
      this['provider'] = {'ID': info.toString()};
    } else if (info is Map) {
      assert(info.containsKey('ID'), 'station info error: $info');
      this['provider'] = info;
    } else {
      assert(info == null, 'provider info error: $info');
      remove('provider');
    }
  }
}
