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
import 'dart:typed_data';

import 'package:lnc/lnc.dart';
import 'package:object_key/object_key.dart';

import '../dim_common.dart';
import 'docker.dart';


abstract class GateKeeper implements DockerDelegate {
  GateKeeper(this.remoteAddress) : _active = false, _lastActive = 0;

  final SocketAddress remoteAddress;

  bool _active;
  double _lastActive;  // last update time (seconds from Jan 1, 1970 UTC)

  bool get isActive => _active;
  bool setActive(bool flag, {double when = 0}) {
    if (_active == flag) {
      // flag not changed
      return false;
    }
    if (when <= 0) {
      when = Time.currentTimeSeconds;
    } else if (when <= _lastActive) {
      return false;
    }
    _active = flag;
    _lastActive = when;
    return true;
  }

  bool queueMessagePackage(ReliableMessage rMsg, Uint8List data,
      {int priority = 0});

  bool sendResponse(Uint8List payload, Arrival ship,
      {required SocketAddress remote, SocketAddress? local});

  //
  //  Docker Delegate
  //

  @override
  Future<void> onDockerStatusChanged(int previous, int current, Docker docker) async {
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
  Future<void> onDockerFailed(Error error, Departure ship, Docker docker) async {
    Log.error("docker failed to send ship: $ship, $docker");
  }

  @override
  Future<void> onDockerError(Error error, Departure ship, Docker docker) async {
    Log.error("docker error while sending ship: $ship, $docker");
  }

}
