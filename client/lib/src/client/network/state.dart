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
import 'package:stargate/stargate.dart';
import 'package:startrek/fsm.dart';
import 'package:startrek/startrek.dart';

import 'session.dart';


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

  String? get sessionKey => session?.key;

  ID? get sessionID => session?.identifier;
  
  @override
  SessionStateMachine get context => this;

  // protected
  SessionStateBuilder createStateBuilder() =>
      SessionStateBuilder(SessionStateTransitionBuilder());

  // @override
  // SessionState? getDefaultState() => super.getDefaultState();

  DockerStatus get status {
    ClientSession? cs = session;
    if (cs == null) {
      return DockerStatus.kError;
    }
    CommonGate gate = cs.gate;
    Docker? docker = gate.getDocker(remote: cs.remoteAddress);
    if (docker == null) {
      return DockerStatus.kError;
    }
    return docker.status;
  }

}


///  Session State Transition
///  ~~~~~~~~~~~~~~~~~~~~~~~~
class SessionStateTransition extends BaseTransition<SessionStateMachine> {
  SessionStateTransition(SessionStateOrder order, this.eval) : super(order.index);

  final SessionStateEvaluate eval;

  @override
  Future<bool> evaluate(SessionStateMachine ctx, DateTime now) => eval(ctx, now);

}

bool _isStateExpired(SessionState? state, DateTime now) {
  DateTime? enterTime = state?.enterTime;
  if (enterTime == null) {
    return false;
  }
  DateTime recent = DateTime.now().subtract(Duration(seconds: 30));
  return enterTime.isBefore(recent);
}

typedef SessionStateEvaluate = Future<bool> Function(SessionStateMachine ctx, DateTime now);

///  Transition Builder
///  ~~~~~~~~~~~~~~~~~~
class SessionStateTransitionBuilder {

  ///  Default -> Connecting
  ///  ~~~~~~~~~~~~~~~~~~~~~
  ///  When the session ID was set, and connection is building.
  ///
  ///  The session key must be empty now, it will be set
  ///  after handshake success.
  getDefaultConnectingTransition() => SessionStateTransition(
    SessionStateOrder.connecting, (ctx, now) async {
      // change to 'connecting' when current user set
      return ctx.sessionID != null;
      // DockerStatus status = ctx.status;
      // return status == DockerStatus.kPreparing || status == DockerStatus.kReady;
    },
  );

  ///  Connecting -> Connected
  ///  ~~~~~~~~~~~~~~~~~~~~~~~
  ///  When connection built.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getConnectingConnectedTransition() => SessionStateTransition(
    SessionStateOrder.connected, (ctx, now) async {
      DockerStatus status = ctx.status;
      return status == DockerStatus.kReady;
    },
  );

  ///  Connecting -> Error
  ///  ~~~~~~~~~~~~~~~~~~~
  ///  When connection lost.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getConnectingErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) async {
      if (_isStateExpired(ctx.currentState, now)) {
        // connecting expired, do it again
        return true;
      }
      DockerStatus status = ctx.status;
      return !(status == DockerStatus.kPreparing || status == DockerStatus.kReady);
    },
  );

  ///  Connected -> Handshaking
  ///  ~~~~~~~~~~~~~~~~~~~~~~~~
  ///  Do handshaking immediately after connected.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getConnectedHandshakingTransition() => SessionStateTransition(
    SessionStateOrder.handshaking, (ctx, now) async {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        //        state will be changed to 'error'
        return false;
      }
      DockerStatus status = ctx.status;
      return status == DockerStatus.kReady;
    },
  );

  ///  Connected -> Error
  ///  ~~~~~~~~~~~~~~~~~~
  ///  When connection lost.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getConnectedErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) async {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        return true;
      }
      DockerStatus status = ctx.status;
      return status != DockerStatus.kReady;
    },
  );

  ///  Handshaking -> Running
  ///  ~~~~~~~~~~~~~~~~~~~~~~
  ///  When session key was set (handshake success).
  ///
  ///  The session ID must be set.
  getHandshakingRunningTransition() => SessionStateTransition(
    SessionStateOrder.running, (ctx, now) async {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        //        state will be changed to 'error'
        return false;
      }
      DockerStatus status = ctx.status;
      if (status != DockerStatus.kReady) {
        // connection lost, state will be changed to 'error'
        return false;
      }
      // when current user changed, the session key will cleared, so
      // if it's set again, it means handshake success
      return ctx.sessionKey != null;
    },
  );

  ///  Handshaking -> Connected
  ///  ~~~~~~~~~~~~~~~~~~~~~~~~
  ///  When handshaking expired.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getHandshakingConnectedTransition() => SessionStateTransition(
    SessionStateOrder.connected, (ctx, now) async {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        //        state will be changed to 'error'
        return false;
      }
      DockerStatus status = ctx.status;
      if (status != DockerStatus.kReady) {
        // connection lost, state will be changed to 'error'
        return false;
      }
      if (ctx.sessionKey != null) {
        // session key was set, state will be changed to 'running'
        return false;
      }
      // handshake expired, do it again
      return _isStateExpired(ctx.currentState, now);
    },
  );

  ///  Handshaking -> Error
  ///  ~~~~~~~~~~~~~~~~~~~~
  ///  When connection lost.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getHandshakingErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) async {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        //        state will be changed to 'error'
        return true;
      }
      DockerStatus status = ctx.status;
      return status != DockerStatus.kReady;
    },
  );

  ///  Running -> Default
  ///  ~~~~~~~~~~~~~~~~~~
  ///  When session id or session key was erased.
  ///
  ///  If session id was erased, it means user logout, the session key
  ///  must be removed at the same time;
  ///  If only session key was erased, but the session id kept the same,
  ///  it means force the user login again.
  getRunningDefaultTransition() => SessionStateTransition(
    SessionStateOrder.init, (ctx, now) async {
      DockerStatus status = ctx.status;
      if (status != DockerStatus.kReady) {
        // connection lost, state will be changed to 'error'
        return false;
      }
      if (ctx.sessionID == null) {
        // user logout / switched?
        return true;
      }
      // force user login again?
      return ctx.sessionKey == null;
    },
  );

  ///  Running -> Error
  ///  ~~~~~~~~~~~~~~~~
  ///  When connection lost.
  getRunningErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) async {
      DockerStatus status = ctx.status;
      return status != DockerStatus.kReady;
    },
  );

  ///  Error -> Default
  ///  ~~~~~~~~~~~~~~~~
  ///  When connection reset.
  getErrorDefaultTransition() => SessionStateTransition(
    SessionStateOrder.init, (ctx, now) async {
      DockerStatus status = ctx.status;
      return status != DockerStatus.kError;
    },
  );

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
