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

import '../dim_network.dart';
import 'group.dart';
import 'network/session.dart';

///  Client Messenger for Handshake & Broadcast Report
abstract class ClientMessenger extends CommonMessenger {
  ClientMessenger(super.session, super.facebook, super.mdb);

  @override
  ClientSession get session => super.session as ClientSession;

  ///  Send handshake command to current station
  ///
  /// @param sessionKey - respond session key
  void handshake(String? sessionKey) {
    Station station = session.station;
    ID sid = station.identifier;
    if (sessionKey == null) {
      // first handshake
      User? user = facebook.currentUser;
      assert(user != null, 'current user not found');
      ID uid = user!.identifier;
      Envelope env = Envelope.create(sender: uid, receiver: sid);
      Content content = HandshakeCommand.start();
      // send first handshake command as broadcast message
      content.group = Station.kEvery;
      // create instant message with meta & visa
      InstantMessage iMsg = InstantMessage.create(env, content);
      iMsg.setMap('meta', user.meta);
      iMsg.setMap('visa', user.visa);
      sendInstantMessage(iMsg, priority: -1);
    } else {
      // handshake again
      Content content = HandshakeCommand.restart(sessionKey);
      sendContent(content, sender: null, receiver: sid, priority: -1);
    }
  }

  ///  Callback for handshake success
  void handshakeSuccess() {
    // broadcast current documents after handshake success
    broadcastDocument();
  }

  ///  Broadcast meta & visa document to all stations
  void broadcastDocument() {
    User? user = facebook.currentUser;
    assert(user != null, 'current user not found');
    ID uid = user!.identifier;
    Content content = DocumentCommand.response(uid, user.meta, user.visa!);
    // broadcast to 'everyone@everywhere'
    sendContent(content, sender: uid, receiver: ID.kEveryone, priority: 1);
  }

  ///  Send login command to keep roaming
  void broadcastLogin(ID sender, String userAgent) {
    Station station = session.station;
    // create login command
    LoginCommand content = LoginCommand.fromID(sender);
    content.agent = userAgent;
    content.station = station;
    // broadcast to 'everyone@everywhere'
    sendContent(content, sender: sender, receiver: ID.kEveryone, priority: 1);
  }

  ///  Send report command to keep user online
  void reportOnline(ID sender) {
    Content content = ReportCommand.fromTitle(ReportCommand.kOnline);
    sendContent(content, sender: sender, receiver: Station.kAny, priority: 1);
  }

  ///  Send report command to let user offline
  void reportOffline(ID sender) {
    Content content = ReportCommand.fromTitle(ReportCommand.kOffline);
    sendContent(content, sender: sender, receiver: Station.kAny, priority: 1);
  }

  @override
  bool queryMeta(ID identifier) {
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isMetaQueryExpired(identifier)) {
      // query not expired yet
      return false;
    }
    Content content = MetaCommand.query(identifier);
    sendContent(content, sender: null, receiver: Station.kAny, priority: 1);
    return true;
  }

  @override
  bool queryDocument(ID identifier) {
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isDocumentQueryExpired(identifier)) {
      // query not expired yet
      return false;
    }
    Content content = DocumentCommand.query(identifier, null);
    sendContent(content, sender: null, receiver: Station.kAny, priority: 1);
    return true;
  }

  @override
  bool queryMembers(ID identifier) {
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isMembersQueryExpired(identifier)) {
      // query not expired yet
      return false;
    }
    assert(identifier.isGroup, "group ID error: $identifier");
    GroupManager manager = GroupManager();
    List<ID> assistants = manager.getAssistants(identifier);
    if (assistants.isEmpty) {
      // group assistants not found
      return false;
    }
    // querying members from bots
    Content content = GroupCommand.query(identifier);
    for (ID bot in assistants) {
      sendContent(content, sender: null, receiver: bot, priority: 1);
    }
    return true;
  }

  @override
  bool checkReceiverInInstantMessage(InstantMessage iMsg) {
    ID receiver = iMsg.receiver;
    if (receiver.isBroadcast) {
      // broadcast message
      return true;
    } else if (receiver.isGroup) {
      // check group's meta & members
      List<ID> members = getMembers(receiver);
      if (members.isEmpty) {
        // group not ready, suspend message for waiting meta/members
        Map<String, String> error = {
          'message': 'group not ready',
          'group': receiver.toString(),
        };
        suspendInstantMessage(iMsg, error);  // iMsg.put("error", error);
        return false;
      }
      List<ID> waiting = [];
      for (ID item in members) {
        if (getVisaKey(item) != null) {
          // member is OK
          continue;
        }
        // member not ready
        waiting.add(item);
      }
      if (waiting.isNotEmpty) {
        // member(s) not ready, suspend message for waiting document
        Map<String, Object> error = {
          'message': 'encrypt keys not found',
          'group': receiver.toString(),
          'members': ID.revert(waiting),
        };
        suspendInstantMessage(iMsg, error);  // iMsg.put("error", error);
        return false;
      }
      // receiver is OK
      return true;
    }
    // check user's meta & document
    return super.checkReceiverInInstantMessage(iMsg);
  }

}
