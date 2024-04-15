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
import 'package:startrek/fsm.dart';
import 'package:startrek/startrek.dart';

import 'session.dart';
import 'state.dart';


///  Session State Transition
///  ~~~~~~~~~~~~~~~~~~~~~~~~
class SessionStateTransition extends BaseTransition<SessionStateMachine> {
  SessionStateTransition(SessionStateOrder order, this.eval) : super(order.index);

  final SessionStateEvaluate eval;

  @override
  bool evaluate(SessionStateMachine ctx, DateTime now) => eval(ctx, now);

}

bool _isStateExpired(SessionState? state, DateTime now) {
  DateTime? enterTime = state?.enterTime;
  if (enterTime == null) {
    return false;
  }
  DateTime recent = DateTime.now().subtract(Duration(seconds: 30));
  return enterTime.isBefore(recent);
}

typedef SessionStateEvaluate = bool Function(SessionStateMachine ctx, DateTime now);


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
    SessionStateOrder.connecting, (ctx, now) {
      // change to 'connecting' when current user set
      if (ctx.sessionID == null) {
        // current user not set yet
        return false;
      }
      DockerStatus status = ctx.status;
      return status == DockerStatus.preparing || status == DockerStatus.ready;
    },
  );

  ///  Connecting -> Connected
  ///  ~~~~~~~~~~~~~~~~~~~~~~~
  ///  When connection built.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getConnectingConnectedTransition() => SessionStateTransition(
    SessionStateOrder.connected, (ctx, now) {
      DockerStatus status = ctx.status;
      return status == DockerStatus.ready;
    },
  );

  ///  Connecting -> Error
  ///  ~~~~~~~~~~~~~~~~~~~
  ///  When connection lost.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getConnectingErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) {
      if (_isStateExpired(ctx.currentState, now)) {
        // connecting expired, do it again
        return true;
      }
      DockerStatus status = ctx.status;
      return !(status == DockerStatus.preparing || status == DockerStatus.ready);
    },
  );

  ///  Connected -> Handshaking
  ///  ~~~~~~~~~~~~~~~~~~~~~~~~
  ///  Do handshaking immediately after connected.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getConnectedHandshakingTransition() => SessionStateTransition(
    SessionStateOrder.handshaking, (ctx, now) {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        //        state will be changed to 'error'
        return false;
      }
      DockerStatus status = ctx.status;
      return status == DockerStatus.ready;
    },
  );

  ///  Connected -> Error
  ///  ~~~~~~~~~~~~~~~~~~
  ///  When connection lost.
  ///
  ///  The session ID must be set, and the session key must be empty now.
  getConnectedErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        return true;
      }
      DockerStatus status = ctx.status;
      return status != DockerStatus.ready;
    },
  );

  ///  Handshaking -> Running
  ///  ~~~~~~~~~~~~~~~~~~~~~~
  ///  When session key was set (handshake success).
  ///
  ///  The session ID must be set.
  getHandshakingRunningTransition() => SessionStateTransition(
    SessionStateOrder.running, (ctx, now) {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        //        state will be changed to 'error'
        return false;
      }
      DockerStatus status = ctx.status;
      if (status != DockerStatus.ready) {
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
    SessionStateOrder.connected, (ctx, now) {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        //        state will be changed to 'error'
        return false;
      }
      DockerStatus status = ctx.status;
      if (status != DockerStatus.ready) {
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
    SessionStateOrder.error, (ctx, now) {
      if (ctx.sessionID == null) {
        // FIXME: current user lost?
        //        state will be changed to 'error'
        return true;
      }
      DockerStatus status = ctx.status;
      return status != DockerStatus.ready;
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
    SessionStateOrder.init, (ctx, now) {
      DockerStatus status = ctx.status;
      if (status != DockerStatus.ready) {
        // connection lost, state will be changed to 'error'
        return false;
      }
      ClientSession? session = ctx.session;
      return session?.isReady != true;
      // if (ctx.sessionID == null) {
      //   // user logout / switched?
      //   return true;
      // }
      // // force user login again?
      // return ctx.sessionKey == null;
    },
  );

  ///  Running -> Error
  ///  ~~~~~~~~~~~~~~~~
  ///  When connection lost.
  getRunningErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) {
      DockerStatus status = ctx.status;
      return status != DockerStatus.ready;
    },
  );

  ///  Error -> Default
  ///  ~~~~~~~~~~~~~~~~
  ///  When connection reset.
  getErrorDefaultTransition() => SessionStateTransition(
    SessionStateOrder.init, (ctx, now) {
      DockerStatus status = ctx.status;
      return status != DockerStatus.error;
    },
  );

}
