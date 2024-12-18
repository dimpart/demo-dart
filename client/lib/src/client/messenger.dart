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

import 'network/session.dart';


///  Client Messenger for Handshake & Broadcast Report
abstract class ClientMessenger extends CommonMessenger {
  ClientMessenger(super.session, super.facebook, super.mdb);

  @override
  ClientSession get session => super.session as ClientSession;

  // // protected
  // ClientArchivist get archivist => facebook.archivist as ClientArchivist;

  @override
  Future<List<ReliableMessage>> processReliableMessage(ReliableMessage rMsg) async {
    List<ReliableMessage> responses = await super.processReliableMessage(rMsg);
    if (responses.isEmpty && await needsReceipt(rMsg)) {
      var res = await buildReceipt(rMsg.envelope);
      if (res != null) {
        responses.add(res);
      }
    }
    return responses;
  }

  // protected
  Future<ReliableMessage?> buildReceipt(Envelope originalEnvelope) async {
    User? currentUser = await facebook.currentUser;
    if (currentUser == null) {
      assert(false, 'failed to get current user');
      return null;
    }
    ID me = currentUser.identifier;
    ID to = originalEnvelope.sender;
    String text = 'Message received.';
    var res = ReceiptCommand.create(text, originalEnvelope, null);
    var env = Envelope.create(sender: me, receiver: to);
    var iMsg = InstantMessage.create(env, res);
    var sMsg = await encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message: $currentUser -> ${originalEnvelope.sender}');
      return null;
    }
    var rMsg = await signMessage(sMsg);
    if (rMsg == null) {
      assert(false, 'failed to sign message: $currentUser -> ${originalEnvelope.sender}');
    }
    return rMsg;
  }

  // protected
  Future<bool> needsReceipt(ReliableMessage rMsg) async {
    if (rMsg.type == ContentType.COMMAND) {
      // filter for looping message (receipt for receipt)
      return false;
    }
    ID sender = rMsg.sender;
    // ID receiver = rMsg.receiver;
    // if (sender.type == EntityType.kStation || sender.type == EntityType.kBot) {
    //   if (receiver.type == EntityType.kStation || receiver.type == EntityType.kBot) {
    //     // message between bots
    //     return false;
    //   }
    // }
    if (sender.type != EntityType.USER/* && receiver.type != EntityType.kUser*/) {
      // message between bots
      return false;
    }
    // User? currentUser = await facebook.currentUser;
    // if (receiver != currentUser.identifier) {
    //   // forward message
    //   return true;
    // }
    // TODO: other condition?
    return true;
  }

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
        return null;
      } else if (content.cmd == HandshakeCommand.HANDSHAKE) {
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
    if (sessionKey == null || sessionKey.isEmpty) {
      // first handshake
      User? user = await facebook.currentUser;
      assert(user != null, 'current user not found');
      ID me = user!.identifier;
      Envelope env = Envelope.create(sender: me, receiver: sid);
      Content content = HandshakeCommand.start();
      // send first handshake command as broadcast message?
      content.group = Station.kEvery;
      // update visa before first handshake
      await updateVisa();
      Meta meta = await user.meta;
      Visa? visa = await user.visa;
      // create instant message with meta & visa
      InstantMessage iMsg = InstantMessage.create(env, content);
      MessageHelper.setMeta(meta, iMsg);
      MessageHelper.setVisa(visa, iMsg);
      await sendInstantMessage(iMsg, priority: -1);
    } else {
      // handshake again
      Content content = HandshakeCommand.restart(sessionKey);
      await sendContent(content, sender: null, receiver: sid, priority: -1);
    }
  }

  Future<bool> updateVisa() async {
    logInfo('TODO: update visa for first handshake');
    return true;
  }

  ///  Callback for handshake success
  Future<void> handshakeSuccess() async {
    // change the flag of current session
    logInfo('handshake success, change session accepted: ${session.isAccepted} => true');
    session.accepted = true;
    // broadcast current documents after handshake success
    await broadcastDocuments();
    // TODO: let a service bot to do this job
  }

  ///  Broadcast meta & visa document to all stations
  Future<void> broadcastDocuments({bool updated = false}) async {
    User? user = await facebook.currentUser;
    assert(user != null, 'current user not found');
    Visa? visa = await user?.visa;
    if (visa == null) {
      assert(false, 'visa not found: $user');
      return;
    }
    ID me = visa.identifier;
    var checker = facebook.checker;
    //
    //  send to all contacts
    //
    List<ID> contacts = await facebook.getContacts(me);
    for (ID item in contacts) {
      await checker.sendVisa(visa, item, updated: updated);
    }
    //
    //  broadcast to 'everyone@everywhere'
    //
    await checker.sendVisa(visa, ID.EVERYONE, updated: updated);
  }

  ///  Send login command to keep roaming
  Future<void> broadcastLogin(ID sender, String userAgent) async {
    Station station = session.station;
    // create login command
    LoginCommand content = LoginCommand.fromID(sender);
    content.agent = userAgent;
    content.station = station;
    // broadcast to 'everyone@everywhere'
    await sendContent(content, sender: sender, receiver: ID.EVERYONE, priority: 1);
  }

  ///  Send report command to keep user online
  Future<void> reportOnline(ID sender) async {
    Content content = ReportCommand.fromTitle(ReportCommand.ONLINE);
    await sendContent(content, sender: sender, receiver: Station.kAny, priority: 1);
  }

  ///  Send report command to let user offline
  Future<void> reportOffline(ID sender) async {
    Content content = ReportCommand.fromTitle(ReportCommand.OFFLINE);
    await sendContent(content, sender: sender, receiver: Station.kAny, priority: 1);
  }

}
