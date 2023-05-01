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
import 'dart:io';

import '../dim_common.dart';
import '../dim_utils.dart';
import 'messenger.dart';
import 'network/session.dart';
import 'network/state.dart';
import 'packer.dart';
import 'processor.dart';

mixin DeviceMixin {

  // "zh-CN"
  String get language;

  // "DIM"
  String get displayName;

  // "1.0.1"
  String get versionName;

  // "4.0"
  String get systemVersion;

  // "HMS"
  String get systemModel;

  // "hammerhead"
  String get systemDevice;

  // "HUAWEI"
  String get deviceBrand;

  // "hammerhead"
  String get deviceBoard;

  // "HUAWEI"
  String get deviceManufacturer;

  ///  format: "DIMP/1.0 (Linux; U; Android 4.1; zh-CN) DIMCoreKit/1.0 (Terminal, like WeChat) DIM-by-GSP/1.0.1"
  String get userAgent {
    String model = systemModel;
    String device = systemDevice;
    String sysVersion = systemVersion;
    String lang = language;

    String appName = displayName;
    String appVersion = versionName;

    return "DIMP/1.0 ($model; U; $device $sysVersion; $lang)"
        " DIMCoreKit/1.0 (Terminal, like WeChat) $appName-by-MOKY/$appVersion";
  }

}

abstract class Terminal with DeviceMixin implements SessionStateDelegate {
  Terminal(this.facebook, this.sdb) : _messenger = null;

  final SessionDBI sdb;
  final CommonFacebook facebook;

  ClientMessenger? _messenger;

  ClientMessenger? get messenger => _messenger;

  ClientSession? get session => _messenger?.session;

  Future<ClientMessenger> connect(String host, int port) async {
    // 0.
    ClientMessenger? old = _messenger;
    if (old != null) {
      ClientSession session = old.session;
      // TODO: check session active?
      Station station = session.station;
      Log.debug('current station: $station');
      if (station.host == host && station.port == port) {
        // same target
        return old;
      }
      session.stop();
      _messenger = null;
    }
    // create session with remote station
    Station station = createStation(host, port);
    Log.debug('connect to new station: $station');
    ClientSession session = createSession(station, SocketAddress(host, port));
    User? user = await facebook.currentUser;
    if (user != null) {
      // set current user for handshaking
      session.setIdentifier(user.identifier);
    }
    // create new messenger with session
    ClientMessenger transceiver = createMessenger(session, facebook);
    _messenger = transceiver;
    // create packer, processor for messenger
    // they have weak references to facebook & messenger
    transceiver.packer = createPacker(facebook, transceiver);
    transceiver.processor = createProcessor(facebook, transceiver);
    // set weak reference to messenger
    session.messenger = transceiver;
    return transceiver;
  }

  // protected
  Station createStation(String host, int port) {
    Station station = Station.fromRemote(host, port);
    station.dataSource = facebook;
    return station;
  }

  // protected
  ClientSession createSession(Station station, SocketAddress remote);
  // ClientSession createSession(Station station, SocketAddress remote) {
  //   ClientSession session = ClientSession(station, remote, sdb);
  //   session.start();
  //   return session;
  // }

  // protected
  Packer createPacker(CommonFacebook facebook, ClientMessenger messenger) {
    return ClientMessagePacker(facebook, messenger);
  }

  // protected
  Processor createProcessor(CommonFacebook facebook, ClientMessenger messenger) {
    return ClientMessageProcessor(facebook, messenger);
  }

  // protected
  ClientMessenger createMessenger(ClientSession session, CommonFacebook facebook);

  bool login(ID current) {
    ClientSession? clientSession = session;
    if (clientSession == null) {
      return false;
    } else {
      clientSession.setIdentifier(current);
      return true;
    }
  }

  Future<void> enterBackground() async {
    ClientMessenger? transceiver = messenger;
    if (transceiver == null) {
      // not connect
      return;
    }
    // check signed in user
    ClientSession session = transceiver.session;
    ID? uid = session.identifier;
    if (uid != null) {
      // already signed in, check session state
      SessionState state = session.state;
      if (state.index == SessionStateOrder.kRunning) {
        // report client state
        await transceiver.reportOffline(uid);
        // sleep a while for waiting 'report' command sent
        sleep(const Duration(milliseconds: 500));
      }
    }
    // pause the session
    session.pause();
  }
  Future<void> enterForeground() async {
    ClientMessenger? transceiver = messenger;
    if (transceiver == null) {
      // not connect
      return;
    }
    ClientSession session = transceiver.session;
    // resume the session
    session.resume();
    // check signed in user
    ID? uid = session.identifier;
    if (uid != null) {
      // already signed in, wait a while to check session state
      sleep(const Duration(milliseconds: 500));
      SessionState state = session.state;
      if (state.index == SessionStateOrder.kRunning) {
        // report client state
        await transceiver.reportOnline(uid);
      }
    }
  }

  // protected
  Future<void> keepOnline(ID uid, ClientMessenger messenger) async {
    if (uid.type == EntityType.kStation) {
      // a station won't login to another station, if here is a station,
      // it must be a station bridge for roaming messages, we just send
      // report command to the target station to keep session online.
      await messenger.reportOnline(uid);
    } else {
      // send login command to everyone to provide more information.
      // this command can keep the user online too.
      await messenger.broadcastLogin(uid, userAgent);
    }
  }

  //
  //  FSM Delegate
  //

  @override
  Future<void> enterState(SessionState next, SessionStateMachine ctx, int now) async {
    // called before state changed
  }

  @override
  Future<void> exitState(SessionState previous, SessionStateMachine ctx, int now) async {
    // called after state changed
    SessionState? current = ctx.currentState;
    if (current == null) {
      return;
    }
    if (current.index == SessionStateOrder.kDefault) {
      // check current user
      ID? user = ctx.sessionID;
      if (user == null) {
        Log.error('current user not set');
        return;
      }
      Log.info('connect for user: $user');
      SocketAddress? remote = session?.remoteAddress;
      if (remote == null) {
        Log.error('failed to get remote address: $session');
        return;
      }
      // TODO: create docker for connecting remote address
      Log.warning('TODO: trying to connect: $remote');
    } else if (current.index == SessionStateOrder.kHandshaking) {
      // start handshake
      await messenger?.handshake(null);
    } else if (current.index == SessionStateOrder.kRunning) {
      // broadcast current meta & visa document to all stations
      await messenger?.handshakeSuccess();
    }
  }

  @override
  Future<void> pauseState(SessionState current, SessionStateMachine ctx, int now) async {

  }

  @override
  Future<void> resumeState(SessionState current, SessionStateMachine ctx, int now) async {
    // TODO: clear session key for re-login?
  }

}
