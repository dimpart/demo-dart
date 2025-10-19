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

import 'package:object_key/object_key.dart';
import 'package:stargate/stargate.dart';
import 'package:dimsdk/dimsdk.dart';

import '../common/dbi/session.dart';
import '../common/messenger.dart';
import '../common/session.dart';

import 'keeper.dart';

abstract class BaseSession extends GateKeeper implements Session {
  BaseSession(this._db, {required super.remote}) {
    _identifier = null;
    _transceiver = null;
  }

  final SessionDBI _db;
  ID? _identifier;
  WeakReference<CommonMessenger>? _transceiver;

  @override
  SessionDBI get database => _db;

  @override
  ID? get identifier => _identifier;

  @override
  bool setIdentifier(ID? user) {
    if (_identifier == null) {
      if (user == null) {
        return false;
      }
    } else if (identifier == user) {
      return false;
    }
    _identifier = user;
    return true;
  }

  CommonMessenger? get messenger => _transceiver?.target;
  set messenger(CommonMessenger? transceiver) =>
      _transceiver = transceiver == null ? null : WeakReference(transceiver);

  @override
  bool queueMessagePackage(ReliableMessage rMsg, Uint8List data, {int priority = 0}) =>
      queueAppend(rMsg, PlainDeparture(data, priority, false));

  //
  //  Transmitter
  //

  @override
  Future<Pair<InstantMessage, ReliableMessage?>> sendContent(Content content, {
    required ID? sender,
    required ID receiver,
    int priority = 0,
  }) async => await messenger!.sendContent(content,
    sender: sender, receiver: receiver, priority: priority,
  );

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {
    int priority = 0,
  }) async => await messenger!.sendInstantMessage(iMsg, priority: priority);

  @override
  Future<bool> sendReliableMessage(ReliableMessage rMsg, {
    int priority = 0,
  }) async => await messenger!.sendReliableMessage(rMsg, priority: priority);

}
