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

import 'package:lnc/lnc.dart';

import '../dim_common.dart';
import 'compatible.dart';
import 'frequency.dart';
import 'network/session.dart';

///  Client Messenger for Handshake & Broadcast Report
abstract class ClientMessenger extends CommonMessenger {
  ClientMessenger(super.session, super.facebook, super.mdb);

  @override
  ClientSession get session => super.session as ClientSession;

  @override
  Future<Uint8List> serializeContent(Content content,
      SymmetricKey password, InstantMessage iMsg) async {
    if (content is Command) {
      content = Compatible.fixCommand(content);
    }
    return await super.serializeContent(content, password, iMsg);
  }

  @override
  Future<Content?> deserializeContent(Uint8List data, SymmetricKey password,
      SecureMessage sMsg) async {
    Content? content = await super.deserializeContent(data, password, sMsg);
    if (content is Command) {
      content = Compatible.fixCommand(content);
    }
    return content;
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
    // broadcast current documents after handshake success
    await broadcastDocument();
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

  ///  Broadcast meta & visa document to all stations
  Future<void> broadcastDocument({bool updated = false}) async {
    User? user = await facebook.currentUser;
    assert(user != null, 'current user not found');
    Visa? visa = await user?.visa;
    if (visa == null) {
      assert(false, 'visa not found: $user');
      return;
    }
    ID me = user!.identifier;
    Meta meta = await user.meta;
    DocumentCommand command = DocumentCommand.response(me, meta, visa);
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    //
    //  send to all contacts
    //
    List<ID> contacts = await facebook.getContacts(me);
    for (ID item in contacts) {
      if (checker.isDocumentResponseExpired(item, force: updated)) {
        Log.info('sending visa to $item');
        await sendContent(command, sender: me, receiver: item, priority: 1);
      } else {
        // not expired yet
        Log.debug('visa response not expired yet: $item');
      }
    }
    //
    //  broadcast to 'everyone@everywhere'
    //
    if (checker.isDocumentResponseExpired(ID.kEveryone, force: updated)) {
      Log.info('sending visa to ${ID.kEveryone}');
      await sendContent(command, sender: me, receiver: ID.kEveryone, priority: 1);
    } else {
      // not expired yet
      Log.debug('visa response not expired yet: ${ID.kEveryone}');
    }
  }

  @override
  Future<bool> queryMeta(ID identifier) async {
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isMetaQueryExpired(identifier)) {
      // query not expired yet
      Log.debug('meta query not expired yet: $identifier');
      return false;
    }
    // build query command for meta
    Content content = MetaCommand.query(identifier);
    await sendContent(content, sender: null, receiver: Station.kAny, priority: 1);
    Log.info('querying meta from any station, ID: $identifier');
    return true;
  }

  @override
  Future<bool> queryDocument(ID identifier) async {
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isDocumentQueryExpired(identifier)) {
      // query not expired yet
      Log.debug('document query not expired yet: $identifier');
      return false;
    }
    // build query command for document
    Content content = DocumentCommand.query(identifier, null);
    await sendContent(content, sender: null, receiver: Station.kAny, priority: 1);
    Log.info('querying document from any station, ID: $identifier');
    return true;
  }

  @override
  Future<bool> queryMembers(ID identifier) async {
    assert(identifier.isGroup, "group ID error: $identifier");
    // 0. check group document
    Document? bulletin = await facebook.getDocument(identifier, '*');
    if (bulletin == null) {
      Log.warning('group document not exists: $identifier');
      queryDocument(identifier);
      return false;
    }
    User? user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isMembersQueryExpired(identifier)) {
      // query not expired yet
      Log.debug('members query not expired yet: $identifier');
      return false;
    }
    // build query command for group members
    QueryCommand command = GroupCommand.query(identifier);
    bool ok;
    // 1. check group bots
    ok = await queryFromAssistants(command, sender: me, group: identifier);
    if (ok) {
      return true;
    }
    // 2. check administrators
    ok = await queryFromAdministrators(command, sender: me, group: identifier);
    if (ok) {
      return true;
    }
    // 3. check group owner
    ok = await queryFromOwner(command, sender: me, group: identifier);
    if (ok) {
      return true;
    }
    // failed
    Log.error('group not ready: $identifier');
    return false;
  }

  // protected
  Future<bool> queryFromAssistants(QueryCommand command, {ID? sender, required ID group}) async {
    List<ID> bots = await facebook.getAssistants(group);
    if (bots.isEmpty) {
      Log.warning('assistants not designated for group: $group');
      return false;
    }
    // querying members from bots
    for (ID receiver in bots) {
      await sendContent(command, sender: sender, receiver: receiver, priority: 1);
    }
    Log.info('querying members from bots: $bots, group: $group');
    return true;
  }

  // protected
  Future<bool> queryFromAdministrators(QueryCommand command, {ID? sender, required ID group}) async {
    AccountDBI? db = facebook.database;
    List<ID> admins = await db.getAdministrators(group: group);
    if (admins.isEmpty) {
      Log.warning('administrators not found for group: $group');
      return false;
    }
    // querying members from admins
    for (ID receiver in admins) {
      await sendContent(command, sender: sender, receiver: receiver, priority: 1);
    }
    Log.info('querying members from admins: $admins, group: $group');
    return true;
  }

  // protected
  Future<bool> queryFromOwner(QueryCommand command, {ID? sender, required ID group}) async {
    ID? owner = await facebook.getOwner(group);
    if (owner == null) {
      Log.warning('owner not found for group: $group');
      return false;
    }
    // querying members from owner
    await sendContent(command, sender: sender, receiver: owner, priority: 1);
    Log.info('querying members from owner: $owner, group: $group');
    return true;
  }

}
