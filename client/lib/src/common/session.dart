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

import 'package:dimp/dimp.dart';

import 'dbi/session.dart';
import 'utils/tuples.dart';

abstract class Transmitter {

  ///  Send content from sender to receiver with priority
  ///
  /// @param sender   - from where, null for current user
  /// @param receiver - to where
  /// @param content  - message content
  /// @param priority - smaller is faster
  /// @return (iMsg, None) on error
  Pair<InstantMessage, ReliableMessage?> sendContent(ID? sender, ID receiver, Content content, int priority);

  ///  Send instant message with priority
  ///
  /// @param iMsg     - plain message
  /// @param priority - smaller is faster
  /// @return null on error
  ReliableMessage? sendInstantMessage(InstantMessage iMsg, int priority);

  ///  Send reliable message with priority
  ///
  /// @param rMsg     - encrypted & signed message
  /// @param priority - smaller is faster
  /// @return false on error
  bool sendReliableMessage(ReliableMessage rMsg, int priority);
}

class SocketAddress extends Pair<String, int> {
  SocketAddress(String host, int port) : super(host, port);

  String get host => first;
  int get port => second;
}

abstract class Session implements Transceiver {

  SessionDBI get database;

  ///  Get remote socket address
  ///
  /// @return host & port
  SocketAddress get remoteAddress;

  /// session key
  String? get key;

  ///  Update user ID
  ///
  /// @param identifier - login user ID
  /// @return true on changed
  bool setIdentifier(ID? user);
  ID? get identifier;

  ///  Update active flag
  ///
  /// @param active - flag
  /// @param when   - now
  /// @return true on changed
  bool setActive(bool flag, int when);
  bool get isActive;

  ///  Pack message into a waiting queue
  ///
  /// @param rMsg     - network message
  /// @param data     - serialized message
  /// @param priority - smaller is faster
  /// @return false on error
  bool queueMessagePackage(ReliableMessage rMsg, Uint8List data, int priority);
}
