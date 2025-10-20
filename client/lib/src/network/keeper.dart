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
import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';
import 'package:stargate/skywalker.dart';
import 'package:stargate/startrek.dart';
import 'package:stargate/websocket.dart';

import 'gate.dart';


class GateKeeper extends Runner with Logging implements PorterDelegate {
  factory GateKeeper() => _instance;
  static final GateKeeper _instance = GateKeeper._internal();
  GateKeeper._internal() : super(Runner.INTERVAL_SLOW) {
    _gate = createGate();
    _hub = createHub(_gate);
    start();
  }

  late final CommonHub _hub;
  late final CommonGate _gate;

  CommonGate get gate => _gate;
  // CommonHub get hub => _hub;

  final Set<PorterDelegate> _listeners = WeakSet();

  void start() {
    _gate.hub = _hub;
    /*await */run();
  }

  // protected
  CommonGate createGate() {
    CommonGate gate =  AckEnableGate();
    gate.delegate = this;
    return gate;
  }

  // protected
  CommonHub createHub(ConnectionDelegate delegate) {
    CommonHub hub = ClientHub();
    hub.delegate = delegate;
    // TODO: reset send buffer size
    return hub;
  }

  void addListener(PorterDelegate delegate) =>
      _listeners.add(delegate);

  void removeListener(PorterDelegate delegate) =>
      _listeners.remove(delegate);

  Future<Connection?> reconnect({required SocketAddress remote}) async {
    // remove old connection
    await disconnect(remote: remote);
    // build new connection
    return await connect(remote: remote);
  }

  Future<Connection?> connect({required SocketAddress remote}) async {
    Connection? conn = await _hub.connect(remote: remote);
    logInfo('new connection: $remote, $conn');
    return conn;
  }

  Future<int> disconnect({required SocketAddress remote}) async {
    int count = 0;
    Connection? conn = _hub.getConnection(remote: remote);
    Connection? cached = _hub.removeConnection(conn, remote: remote);
    if (cached == null || identical(cached, conn)) {} else {
      logWarning('close cached connection: $remote, $cached');
      await cached.close();
      count += 1;
    }
    if (conn != null) {
      logWarning('close connection: $remote, $conn');
      await conn.close();
      count += 1;
    }
    return count;
  }

  @override
  Future<bool> process() async {
    // try to process income/outgo packages
    try {
      bool incoming = await _gate.hub?.process() ?? false;
      bool outgoing = await _gate.process();
      if (incoming || outgoing) {
        // processed income/outgo packages
        return true;
      }
    } catch (e, st) {
      logError('gate process error: $e, $st');
      return false;
    }
    return true;
  }

  //
  //  Docker Delegate
  //

  @override
  Future<void> onPorterStatusChanged(PorterStatus previous, PorterStatus current, Porter porter) async {
    logInfo('docker status changed: $previous => $current, $porter, calling ${_listeners.length} listeners');
    for (var delegate in _listeners) {
      await delegate.onPorterStatusChanged(previous, current, porter);
    }
  }

  @override
  Future<void> onPorterReceived(Arrival ship, Porter porter) async {
    logDebug('docker received a ship: $ship, $porter, calling ${_listeners.length} listeners');
    for (var delegate in _listeners) {
      await delegate.onPorterReceived(ship, porter);
    }
  }

  @override
  Future<void> onPorterSent(Departure ship, Porter porter) async {
    // TODO: remove sent message from local cache
    for (var delegate in _listeners) {
      await delegate.onPorterSent(ship, porter);
    }
  }

  @override
  Future<void> onPorterFailed(IOError error, Departure ship, Porter porter) async {
    logError('docker failed to send ship: $ship, $porter, calling ${_listeners.length} listeners');
    for (var delegate in _listeners) {
      await delegate.onPorterFailed(error, ship, porter);
    }
  }

  @override
  Future<void> onPorterError(IOError error, Departure ship, Porter porter) async {
    logError('docker error while sending ship: $ship, $porter, calling ${_listeners.length} listeners');
    for (var delegate in _listeners) {
      await delegate.onPorterError(error, ship, porter);
    }
  }

}
