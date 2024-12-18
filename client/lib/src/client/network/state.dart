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
import 'package:stargate/fsm.dart';
import 'package:stargate/stargate.dart';
import 'package:stargate/startrek.dart';

import 'session.dart';
import 'transition.dart';


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
class SessionStateMachine
    extends AutoMachine<SessionStateMachine, SessionStateTransition, SessionState>
    implements MachineContext {
  SessionStateMachine(ClientSession session) : _sessionRef = WeakReference(session) {
    // init states
    SessionStateBuilder builder = createStateBuilder();
    addState(builder.getDefaultState());
    addState(builder.getConnectingState());
    addState(builder.getConnectedState());
    addState(builder.getHandshakingState());
    addState(builder.getRunningState());
    addState(builder.getErrorState());
  }

  final WeakReference<ClientSession> _sessionRef;

  ClientSession? get session => _sessionRef.target;

  String? get sessionKey => session?.sessionKey;

  ID? get sessionID => session?.identifier;
  
  @override
  SessionStateMachine get context => this;

  // protected
  SessionStateBuilder createStateBuilder() =>
      SessionStateBuilder(SessionStateTransitionBuilder());

  // @override
  // SessionState? getDefaultState() => super.getDefaultState();

  PorterStatus get status {
    ClientSession? cs = session;
    if (cs == null) {
      return PorterStatus.error;
    }
    CommonGate gate = cs.gate;
    Porter? docker = gate.getPorter(remote: cs.remoteAddress);
    if (docker == null) {
      return PorterStatus.error;
    }
    return docker.status;
  }

}


///  Session State Delegate
///  ~~~~~~~~~~~~~~~~~~~~~~
///
///  callback when session state changed
abstract interface class SessionStateDelegate
    implements MachineDelegate<SessionStateMachine, SessionStateTransition, SessionState> {}

enum SessionStateOrder {
  init,  // default
  connecting,
  connected,
  handshaking,
  running,
  error,
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
class SessionState extends BaseState<SessionStateMachine, SessionStateTransition> {
  SessionState(SessionStateOrder order) : super(order.index) {
    name = order.name;
  }

  late final String name;
  DateTime? _enterTime;

  DateTime? get enterTime => _enterTime;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) {
    if (other is ConnectionState) {
      if (identical(this, other)) {
        // same object
        return true;
      }
      return index == other.index;
    } else if (other is ConnectionStateOrder) {
      return index == other.index;
    } else {
      return false;
    }
  }

  @override
  int get hashCode => index;

  @override
  Future<void> onEnter(State<SessionStateMachine, SessionStateTransition>? previous,
      SessionStateMachine ctx, DateTime now) async {
    _enterTime = now;
  }

  @override
  Future<void> onExit(State<SessionStateMachine, SessionStateTransition>? next,
      SessionStateMachine ctx, DateTime now) async {
    _enterTime = null;
  }

  @override
  Future<void> onPause(SessionStateMachine ctx, DateTime now) async {
  }

  @override
  Future<void> onResume(SessionStateMachine ctx, DateTime now) async {
  }

}

///  State Builder
///  ~~~~~~~~~~~~~
class SessionStateBuilder {
  SessionStateBuilder(this.stb);

  final SessionStateTransitionBuilder stb;

  getDefaultState() {
    SessionState state = SessionState(SessionStateOrder.init);
    // Default -> Connecting
    state.addTransition(stb.getDefaultConnectingTransition());
    return state;
  }

  getConnectingState() {
    SessionState state = SessionState(SessionStateOrder.connecting);
    // Connecting -> Connected
    state.addTransition(stb.getConnectingConnectedTransition());
    // Connecting -> Error
    state.addTransition(stb.getConnectingErrorTransition());
    return state;
  }

  getConnectedState() {
    SessionState state = SessionState(SessionStateOrder.connected);
    // Connected -> Handshaking
    state.addTransition(stb.getConnectedHandshakingTransition());
    // Connected -> Error
    state.addTransition(stb.getConnectedErrorTransition());
    return state;
  }

  getHandshakingState() {
    SessionState state = SessionState(SessionStateOrder.handshaking);
    // Handshaking -> Running
    state.addTransition(stb.getHandshakingRunningTransition());
    // Handshaking -> Connected
    state.addTransition(stb.getHandshakingConnectedTransition());
    // Handshaking -> Error
    state.addTransition(stb.getHandshakingErrorTransition());
    return state;
  }

  getRunningState() {
    SessionState state = SessionState(SessionStateOrder.running);
    // Running -> Default
    state.addTransition(stb.getRunningDefaultTransition());
    // Running -> Error
    state.addTransition(stb.getRunningErrorTransition());
    return state;
  }

  getErrorState() {
    SessionState state = SessionState(SessionStateOrder.error);
    // Error -> Default
    state.addTransition(stb.getErrorDefaultTransition());
    return state;
  }

}
