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
import 'package:dimsdk/dimsdk.dart';

import '../common/messenger.dart';
import '../common/protocol/handshake.dart';
import '../common/protocol/login.dart';
import '../common/protocol/report.dart';

import 'archivist.dart';
import 'network/session.dart';


///  Client Messenger for Handshake & Broadcast Report
abstract class ClientMessenger extends CommonMessenger {
  ClientMessenger(super.session, super.facebook, super.mdb);

  @override
  ClientSession get session => super.session as ClientSession;

  // protected
  ClientArchivist get archivist => facebook.archivist as ClientArchivist;

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    if (session.isReady) {
      // OK, any message can go out
    } else {
      // not login yet
      Content content = iMsg.content;
      if (content is! Command) {
        logWarning('not handshake yet, suspend message: $content => ${iMsg.receiver}');
        // TODO: suspend instant message
      } else if (content.cmd == HandshakeCommand.kHandshake) {
        // NOTICE: only handshake message can go out
        iMsg['pass'] = 'handshaking';
      } else {
        logWarning('not handshake yet, drop command: $content => ${iMsg.receiver}');
        // TODO: suspend instant message
        return null;
      }
    }
    return await super.sendInstantMessage(iMsg, priority: priority);
  }

  @override
  Future<bool> sendReliableMessage(ReliableMessage rMsg, {int priority = 0}) async {
    var passport = rMsg.remove('pass');
    if (session.isReady) {
      // OK, any message can go out
      assert(passport == null, 'should not happen: $rMsg');
    } else if (passport == 'handshaking') {
      // not login in yet, let the handshake message go out only
    } else {
      logError('not handshake yet, suspend message: ${rMsg.sender} => ${rMsg.receiver}');
      // TODO: suspend reliable message
      return false;
    }
    return await super.sendReliableMessage(rMsg, priority: priority);
  }

  ///  Send handshake command to current station
  ///
  /// @param sessionKey - respond session key
  Future<void> handshake(String? sessionKey) async {
    Station station = session.station;
    ID sid = station.identifier;
    if (sessionKey == null) {
      // first handshake
      User? user = await facebook.currentUser;
      assert(user != null, 'current user not found');
      ID me = user!.identifier;
      Envelope env = Envelope.create(sender: me, receiver: sid);
      Content content = HandshakeCommand.start();
      // send first handshake command as broadcast message
      content.group = Station.kEvery;
      // create instant message with meta & visa
      InstantMessage iMsg = InstantMessage.create(env, content);
      iMsg.setMap('meta', await user.meta);
      iMsg.setMap('visa', await user.visa);
      await sendInstantMessage(iMsg, priority: -1);
    } else {
      // handshake again
      Content content = HandshakeCommand.restart(sessionKey);
      await sendContent(content, sender: null, receiver: sid, priority: -1);
    }
  }

  ///  Callback for handshake success
  Future<void> handshakeSuccess() async {
    // change the flag of current session
    logInfo('handshake success, change session accepted: ${session.isAccepted} => true');
    session.accepted = true;
    // broadcast current documents after handshake success
    await broadcastDocument();
    // TODO: let a service bot to do this job
  }

  ///  Broadcast meta & visa document to all stations
  Future<void> broadcastDocument({bool updated = false}) async {
    User? user = await facebook.currentUser;
    assert(user != null, 'current user not found');
    Visa? visa = await user?.visa;
    if (visa == null) {
      assert(false, 'visa not found: $user');
      return;
    }
    ID me = visa.identifier;
    //
    //  send to all contacts
    //
    List<ID> contacts = await facebook.getContacts(me);
    for (ID item in contacts) {
      await archivist.sendDocument(visa, item, updated: updated);
    }
    //
    //  broadcast to 'everyone@everywhere'
    //
    await archivist.sendDocument(visa, ID.kEveryone, updated: updated);
  }

  ///  Send login command to keep roaming
  Future<void> broadcastLogin(ID sender, String userAgent) async {
    Station station = session.station;
    // create login command
    LoginCommand content = LoginCommand.fromID(sender);
    content.agent = userAgent;
    content.station = station;
    // broadcast to 'everyone@everywhere'
    await sendContent(content, sender: sender, receiver: ID.kEveryone, priority: 1);
  }

  ///  Send report command to keep user online
  Future<void> reportOnline(ID sender) async {
    Content content = ReportCommand.fromTitle(ReportCommand.kOnline);
    await sendContent(content, sender: sender, receiver: Station.kAny, priority: 1);
  }

  ///  Send report command to let user offline
  Future<void> reportOffline(ID sender) async {
    Content content = ReportCommand.fromTitle(ReportCommand.kOffline);
    await sendContent(content, sender: sender, receiver: Station.kAny, priority: 1);
  }

}
