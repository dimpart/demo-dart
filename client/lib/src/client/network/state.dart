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

import 'session.dart';


class SessionStateOrder {

  static const int kDefault     =  0;
  static const int kConnecting  =  1;
  static const int kConnected   =  2;
  static const int kHandshaking =  3;
  static const int kRunning     =  4;
  static const int kError       = -1;

}


///  Session State
///  ~~~~~~~~~~~~~
///
///  Defined for indicating session states
///
///      DEFAULT     - initialized
///      CONNECTING  - connecting to station
///      CONNECTED   - connected to station
///      HANDSHAKING - trying to log in
///      RUNNING     - handshake accepted
///      ERROR       - network error
class SessionState {
  SessionState(this.index);

  /// state order
  final int index;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz index=$index name="${_sessionStateName(index)}" />';
  }

}

String _sessionStateName(int index) {
  switch (index) {
    case SessionStateOrder.kDefault:
      return 'Default';
    case SessionStateOrder.kConnecting:
      return 'Connecting';
    case SessionStateOrder.kConnected:
      return 'Connected';
    case SessionStateOrder.kHandshaking:
      return 'Handshaking';
    case SessionStateOrder.kRunning:
      return 'Running';
    case SessionStateOrder.kError:
      return 'Error';
    default:
      return 'Unknown($index)';
  }
}


///  Session States
///  ~~~~~~~~~~~~~~
///
///      +--------------+                +------------------+
///      |  0.Default   | .............> |   1.Connecting   |
///      +--------------+                +------------------+
///          A       A       ................:       :
///          :       :       :                       :
///          :       :       V                       V
///          :   +--------------+        +------------------+
///          :   |   5.Error    | <..... |   2.Connected    |
///          :   +--------------+        +------------------+
///          :       A       A                   A   :
///          :       :       :................   :   :
///          :       :                       :   :   V
///      +--------------+                +------------------+
///      |  4.Running   | <............. |  3.Handshaking   |
///      +--------------+                +------------------+
///
abstract class SessionStateMachine {
  SessionStateMachine(ClientSession session)
      : _sessionRef = WeakReference(session);

  final WeakReference<ClientSession> _sessionRef;

  ClientSession? get session => _sessionRef.target;

  String? get sessionKey => session?.key;

  ID? get sessionID => session?.identifier;

  SessionState? get currentState;

}


abstract class SessionStateDelegate {

  ///  Called before new state entered
  ///  (get current state from context)
  ///
  /// @param next     - new state
  /// @param ctx      - context (machine)
  /// @param now      - current time (milliseconds, from Jan 1, 1970 UTC)
  Future<void> enterState(SessionState next, SessionStateMachine ctx, int now);

  ///  Called after old state exited
  ///  (get current state from context)
  ///
  /// @param previous - old state
  /// @param ctx      - context (machine)
  /// @param now      - current time (milliseconds, from Jan 1, 1970 UTC)
  Future<void> exitState(SessionState previous, SessionStateMachine ctx, int now);

  ///  Called after current state paused
  ///
  /// @param current  - current state
  /// @param ctx      - context (machine)
  /// @param now      - current time (milliseconds, from Jan 1, 1970 UTC)
  Future<void> pauseState(SessionState current, SessionStateMachine ctx, int now);

  ///  Called before current state resumed
  ///
  /// @param current  - current state
  /// @param ctx      - context (machine)
  /// @param now      - current time (milliseconds, from Jan 1, 1970 UTC)
  Future<void> resumeState(SessionState current, SessionStateMachine ctx, int now);

}
