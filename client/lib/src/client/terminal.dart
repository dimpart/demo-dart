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
import 'package:lnc/log.dart';
import 'package:stargate/skywalker.dart' show Runner;
import 'package:stargate/startrek.dart';

import '../common/dbi/session.dart';
import '../common/facebook.dart';

import 'messenger.dart';
import 'network/session.dart';
import 'network/state.dart';

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

abstract class Terminal extends Runner with DeviceMixin, Logging
    implements SessionStateDelegate {
  Terminal(this.facebook, this.database)
      : super(ACTIVE_INTERVAL);

  // ignore: non_constant_identifier_names
  static Duration ACTIVE_INTERVAL = Duration(seconds: 60);

  final SessionDBI database;
  final CommonFacebook facebook;

  ClientMessenger? _messenger;

  DateTime? _lastOnlineTime;

  ClientMessenger? get messenger => _messenger;

  ClientSession? get session => _messenger?.session;

  //
  //  Connection
  //

  Future<ClientMessenger> connect(String host, int port) async {
    // check old session
    ClientMessenger? old = _messenger;
    if (old != null) {
      ClientSession session = old.session;
      if (session.isActive) {
        // current session is active
        Station station = session.station;
        logDebug('current station: $station');
        if (station.port == port && station.host == host) {
          // same target
          logWarning('active session connected to $host:$port .');
          return old;
        }
        await session.stop();
      }
      _messenger = null;
    }
    logInfo('connecting to $host:$port ...');
    // create new messenger with session
    Station station = createStation(host, port);
    ClientSession session = createSession(station);
    // create new messenger with session
    ClientMessenger transceiver = createMessenger(session, facebook);
    _messenger = transceiver;
    // create packer, processor for messenger
    // they have weak references to facebook & messenger
    transceiver.packer = createPacker(facebook, transceiver);
    transceiver.processor = createProcessor(facebook, transceiver);
    // set weak reference to messenger
    session.messenger = transceiver;
    // login with current user
    User? user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
    } else {
      session.setIdentifier(user.identifier);
    }
    return transceiver;
  }

  // protected
  Station createStation(String host, int port) {
    Station station = Station.fromRemote(host, port);
    station.dataSource = facebook;
    return station;
  }

  // protected
  ClientSession createSession(Station station) {
    ClientSession session = ClientSession(database, station);
    session.start(this);
    return session;
  }

  // protected
  Packer createPacker(CommonFacebook facebook, ClientMessenger messenger);

  // protected
  Processor createProcessor(CommonFacebook facebook, ClientMessenger messenger);

  // protected
  ClientMessenger createMessenger(ClientSession session, CommonFacebook facebook);

  bool login(ID user) {
    ClientSession? cs = session;
    if (cs == null) {
      return false;
    }
    cs.setIdentifier(user);
    return true;
  }

  //
  //  App Lifecycle
  //

  Future<void> enterBackground() async {
    ClientMessenger? transceiver = messenger;
    if (transceiver == null) {
      // not connect
      return;
    }
    // check signed in user
    ClientSession cs = transceiver.session;
    ID? uid = cs.identifier;
    if (uid != null) {
      // already signed in, check session state
      SessionState? state = cs.state;
      if (state?.index == SessionStateOrder.running.index) {
        // report client state
        await transceiver.reportOffline(uid);
        // sleep a while for waiting 'report' command sent
        await Runner.sleep(Duration(milliseconds: 512));
      }
    }
    // pause the session
    await cs.pause();
  }
  Future<void> enterForeground() async {
    ClientMessenger? transceiver = messenger;
    if (transceiver == null) {
      // not connect
      return;
    }
    ClientSession cs = transceiver.session;
    // resume the session
    await cs.resume();
    // check signed in user
    ID? uid = cs.identifier;
    if (uid != null) {
      // already signed in, wait a while to check session state
      await Runner.sleep(Duration(milliseconds: 512));
      SessionState? state = cs.state;
      if (state?.index == SessionStateOrder.running.index) {
        // report client state
        await transceiver.reportOnline(uid);
      }
    }
  }

  //
  //  Threading
  //

  Future<void> start() async {
    if (isRunning) {
      await stop();
      await idle();
    }
    /*await */run();
  }

  @override
  Future<void> finish() async {
    // stop session in messenger
    ClientMessenger? transceiver = messenger;
    if (transceiver != null) {
      _messenger = null;
      ClientSession cs = transceiver.session;
      await cs.stop();
    }
    await super.finish();
  }

  @override
  Future<void> idle() async =>
      await Runner.sleep(Duration(seconds: 16));

  @override
  Future<bool> process() async {
    //
    //  1. check connection
    //
    if (session?.state?.index != SessionStateOrder.running.index) {
      // handshake not accepted
      return false;
    } else if (session?.isReady != true) {
      // session not ready
      return false;
    }
    //
    //  2. check timeout
    //
    DateTime now = DateTime.now();
    if (needsKeepOnline(_lastOnlineTime, now)) {
      // update last online time
      _lastOnlineTime = now;
    } else {
      // not expired yet
      return false;
    }
    //
    //  3. try to report every 5 minutes to keep user online
    //
    try {
      await keepOnline();
    } catch (e) {
      logError('Terminal error: $e');
    }
    return false;
  }

  // protected
  bool needsKeepOnline(DateTime? last, DateTime now) {
    if (last == null) {
      // not login yet
      return false;
    }
    // keep online every 5 minutes
    return last.add(Duration(seconds: 300)).isBefore(now);
  }

  // protected
  Future<void> keepOnline() async {
    User? user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
    } else if (user.type == EntityType.STATION) {
      // a station won't login to another station, if here is a station,
      // it must be a station bridge for roaming messages, we just send
      // report command to the target station to keep session online.
      await messenger?.reportOnline(user.identifier);
    } else {
      // send login command to everyone to provide more information.
      // this command can keep the user online too.
      await messenger?.broadcastLogin(user.identifier, userAgent);
    }
  }

  //
  //  FSM Delegate
  //

  @override
  Future<void> enterState(SessionState? next, SessionStateMachine ctx, DateTime now) async {
    // called before state changed
  }

  @override
  Future<void> exitState(SessionState? previous, SessionStateMachine ctx, DateTime now) async {
    // called after state changed
    SessionState? current = ctx.currentState;
    if (current == null || current.index == SessionStateOrder.error.index) {
      _lastOnlineTime = null;
      return;
    }
    if (current.index == SessionStateOrder.init.index ||
        current.index == SessionStateOrder.connecting.index) {
      // check current user
      ID? user = ctx.sessionID;
      if (user == null) {
        logWarning('current user not set');
        return;
      }
      logInfo('connect for user: $user');
      SocketAddress? remote = session?.remoteAddress;
      if (remote == null) {
        logWarning('failed to get remote address: $session');
        return;
      }
      Porter? docker = await session?.gate.fetchPorter(remote: remote);
      if (docker == null) {
        logError('failed to connect: $remote');
      } else {
        logInfo('connected to: $remote');
      }
    } else if (current.index == SessionStateOrder.handshaking.index) {
      // start handshake
      await messenger?.handshake(null);
    } else if (current.index == SessionStateOrder.running.index) {
      // broadcast current meta & visa document to all stations
      await messenger?.handshakeSuccess();
      // update last online time
      _lastOnlineTime = now;
    }
  }

  @override
  Future<void> pauseState(SessionState? current, SessionStateMachine ctx, DateTime now) async {

  }

  @override
  Future<void> resumeState(SessionState? current, SessionStateMachine ctx, DateTime now) async {
    // TODO: clear session key for re-login?
  }

}
