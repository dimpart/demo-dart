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
import 'package:lnc/lnc.dart';
import 'package:stargate/websocket.dart';
import 'package:startrek/fsm.dart';
import 'package:startrek/startrek.dart';

import 'queue.dart';


abstract class GateKeeper extends Runner implements DockerDelegate {
  GateKeeper({required SocketAddress remote}) {
    _remoteAddress = remote;
    _gate = createGate(remote);
    _queue = MessageQueue();
    _active = false;
    _lastActiveTime = null;
  }

  late final SocketAddress _remoteAddress;
  late final CommonGate _gate;
  late final MessageQueue _queue;
  late bool _active;
  late DateTime? _lastActiveTime;  // last update time

  // protected
  CommonGate createGate(SocketAddress remote) {
    CommonGate gate = ClientGate(this);
    gate.hub = createHub(gate, remote);
    return gate;
  }

  // protected
  StreamHub createHub(ConnectionDelegate delegate, SocketAddress remote) {
    ClientHub hub = ClientHub(delegate);
    // Connection? conn = await hub.connect(remote: remote);
    // assert(conn != null, 'failed to connect remote: $remote');
    // TODO: reset send buffer size
    return hub;
  }

  SocketAddress get remoteAddress => _remoteAddress;

  CommonGate get gate => _gate;

  bool get isActive => _active;
  bool setActive(bool flag, DateTime? when) {
    if (_active == flag) {
      // flag not changed
      return false;
    }
    DateTime? last = _lastActiveTime;
    if (when == null) {
      when = DateTime.now();
    } else if (last != null && last.isAfter(when)) {
      return false;
    }
    _active = flag;
    _lastActiveTime = when;
    return true;
  }

  @override
  bool get isRunning => super.isRunning ? _gate.isRunning : false;

  @override
  Future<void> stop() async {
    await super.stop();
    await _gate.stop();
  }

  @override
  Future<void> setup() async {
    await super.setup();
    Connection? conn = await _gate.hub?.connect(remote: _remoteAddress);
    assert(conn != null, 'failed to connect remote: $_remoteAddress');
    await _gate.start();
  }

  @override
  Future<void> finish() async {
    await _gate.stop();
    await super.finish();
  }

  @override
  Future<bool> process() async {
    Hub? hub = _gate.hub;
    if (hub == null) {
      assert(false, 'gate hub not found');
      return false;
    }
    try {
      bool incoming = await hub.process();
      bool outgoing = await _gate.process();
      if (incoming || outgoing) {
        // processed income/outgo packages
        return true;
      }
    } catch (e) {
      Log.error('gate process error: $e');
      return false;
    }
    if (!isActive) {
      // inactive, wait a while to check again
      _queue.purge();
      return false;
    }
    // get next message
    MessageWrapper? wrapper = _queue.next();
    if (wrapper == null) {
      // no more task now, purge failed task
      _queue.purge();
      return false;
    }
    // if msg in this wrapper is null (means sent successfully),
    // it must have bean cleaned already, so iit should not be empty here
    ReliableMessage? msg = wrapper.message;
    if (msg == null) {
      // msg sent?
      return true;
    }
    // try to push
    bool ok = await _gate.sendShip(wrapper, remote: _remoteAddress);
    if (!ok) {
      Log.error('gate error, failed to send data');
    }
    return true;
  }

  // // protected
  // Future<Departure> dockerPack(Uint8List payload, int priority) async {
  //   Docker? docker = await _gate.fetchDocker([], remote: remoteAddress);
  //   return (docker as DeparturePacker).packData(payload, priority);
  // }

  // protected
  bool queueAppend(ReliableMessage rMsg, Departure ship) => _queue.append(rMsg, ship);

  //
  //  Docker Delegate
  //

  @override
  Future<void> onDockerStatusChanged(DockerStatus previous, DockerStatus current, Docker docker) async {
    Log.info('docker status changed: $previous => $current, $docker');
  }

  @override
  Future<void> onDockerReceived(Arrival ship, Docker docker) async {
    Log.debug("docker received a ship: $ship, $docker");
  }

  @override
  Future<void> onDockerSent(Departure ship, Docker docker) async {
    // TODO: remove sent message from local cache
  }

  @override
  Future<void> onDockerFailed(IOError error, Departure ship, Docker docker) async {
    Log.error("docker failed to send ship: $ship, $docker");
  }

  @override
  Future<void> onDockerError(IOError error, Departure ship, Docker docker) async {
    Log.error("docker error while sending ship: $ship, $docker");
  }

}
