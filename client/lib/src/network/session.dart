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
import '../dim_common.dart';

import 'gate.dart';

abstract class BaseSession extends GateKeeper implements Session {
  BaseSession(super.remoteAddress, this.database) {
    _identifier = null;
    _transceiver = null;
  }

  @override
  final SessionDBI database;

  ID? _identifier;
  WeakReference<CommonMessenger>? _transceiver;

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
  set messenger(CommonMessenger? transceiver)
  => _transceiver = transceiver == null ? null : WeakReference(transceiver);

  //
  //  Transmitter
  //

  @override
  Future<Pair<InstantMessage, ReliableMessage?>> sendContent(Content content,
      {required ID? sender, required ID receiver, int priority = 0}) async {
    return await messenger!.sendContent(content,
        sender: sender, receiver: receiver, priority: priority);
  }

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg,
      {int priority = 0}) async {
    return await messenger!.sendInstantMessage(iMsg, priority: priority);
  }

  @override
  Future<bool> sendReliableMessage(ReliableMessage rMsg, {int priority = 0}) async {
    return await messenger!.sendReliableMessage(rMsg, priority: priority);
  }

}
