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
import 'package:lnc/lnc.dart';
import 'package:object_key/object_key.dart';

import '../dim_common.dart';
import 'frequency.dart';
import 'network/session.dart';

///  Client Messenger for Handshake & Broadcast Report
abstract class ClientMessenger extends CommonMessenger {
  ClientMessenger(super.session, super.facebook, super.mdb);

  @override
  ClientSession get session => super.session as ClientSession;

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
    // send to all contacts
    List<ID> contacts = await facebook.getContacts(me);
    for (ID item in contacts) {
      await _sendVisa(command, sender: me, receiver: item, force: updated);
    }
    // broadcast to 'everyone@everywhere'
    await _sendVisa(command, sender: me, receiver: ID.kEveryone, force: updated);
  }

  Future<bool> _sendVisa(DocumentCommand command,
      {required ID receiver, ID? sender, bool force = false}) async {
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isDocumentResponseExpired(receiver, force: force)) {
      // response not expired yet
      Log.debug('visa response not expired yet: $receiver');
      return false;
    }
    Log.info('push visa to: $receiver');
    var pair = await sendContent(command, sender: sender, receiver: receiver, priority: 1);
    return pair.second != null;
  }

  @override
  Future<bool> queryMeta(ID identifier) async {
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isMetaQueryExpired(identifier)) {
      // query not expired yet
      Log.debug('meta query not expired yet: $identifier');
      return false;
    }
    Log.info('querying meta from any station, ID: $identifier');
    Content content = MetaCommand.query(identifier);
    await sendContent(content, sender: null, receiver: Station.kAny, priority: 1);
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
    Log.info('querying document from any station, ID: $identifier');
    Content content = DocumentCommand.query(identifier, null);
    await sendContent(content, sender: null, receiver: Station.kAny, priority: 1);
    return true;
  }

  @override
  Future<bool> queryMembers(ID identifier) async {
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isMembersQueryExpired(identifier)) {
      // query not expired yet
      Log.debug('members query not expired yet: $identifier');
      return false;
    }
    assert(identifier.isGroup, "group ID error: $identifier");
    Content content = GroupCommand.query(identifier);
    // 1. check group bots
    List<ID> bots = await facebook.getAssistants(identifier);
    if (bots.isNotEmpty) {
      // querying members from bots
      Log.info('querying members from bots: $bots, group: $identifier');
      for (ID receiver in bots) {
        await sendContent(content, sender: null, receiver: receiver, priority: 1);
      }
      return true;
    }
    // 2.. check group owner
    ID? owner = await facebook.getOwner(identifier);
    if (owner != null) {
      // querying members from owner
      Log.info('querying members from owner: $owner, group: $identifier');
      await sendContent(content, sender: null, receiver: owner, priority: 1);
      return true;
    }
    Log.warning('group not ready: $identifier');
    return false;
  }

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    ID receiver = iMsg.receiver;
    // NOTICE: because group assistant (bot) cannot be a member of the group, so
    //         if you want to send a group command to any assistant, you must
    //         set the bot ID as 'receiver' and set the group ID in content;
    //         this means you must send it to the bot directly.
    if (receiver.isGroup) {
      // so this is a group message (not split yet)
      return await sendGroupMessage(iMsg, priority: priority);
    }
    // this message is sending to a user/member/bot directly
    return await super.sendInstantMessage(iMsg, priority: priority);
  }

  // protected
  Future<ReliableMessage?> sendGroupMessage(InstantMessage iMsg, {required int priority}) async {
    assert(iMsg.containsKey('group') == false, 'should not happen');
    ID group = iMsg.receiver;
    assert(group.isGroup, 'group ID error: $group');

    // 0. check group bots
    List<ID> bots = await facebook.getAssistants(group);
    if (bots.isEmpty) {
      // no 'assistants' found in group's bulletin document?
      // split group messages and send to all members one by one
      int ok = await _splitGroupMessage(group, iMsg, priority: priority);
      assert(ok > 0, 'failed to split message for group: $group');
      // TODO:
      return null;
    }

    // group bots designated, let group bot to split the message, so
    // here must expose the group ID; this will cause the client to
    // use a "user-to-group" encrypt key to encrypt the message content,
    // this key will be encrypted by each member's public key, so
    // all members will received a message split by the group bot,
    // but the group bots cannot decrypt it.
    iMsg.setString('group', group);

    // 1. pack message
    SecureMessage? sMsg = await encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message for group: $group');
      return null;
    }
    ReliableMessage? rMsg = await signMessage(sMsg);
    if (rMsg == null) {
      assert(false, 'failed to sign message: ${iMsg.sender} => $group');
      return null;
    }

    // 2. forward the group message to any bot
    ID prime = bots[0];
    Content content = ForwardContent.create(forward: rMsg);
    Pair pair = await sendContent(content, sender: null, receiver: prime, priority: priority);
    return pair.second;
  }

  /// split group messages and send to all members one by one
  Future<int> _splitGroupMessage(ID group, InstantMessage iMsg, {required int priority}) async {
    // get members
    List<ID> allMembers = await facebook.getMembers(group);
    if (allMembers.isEmpty) {
      assert(false, 'group empty: $group');
      return -1;
    }
    int success = 0;
    // split messages
    InstantMessage? item;
    ReliableMessage? res;
    for (ID member in allMembers) {
      Log.info('split group message for member: $member, group: $group');
      Map info = iMsg.copyMap(false);
      // replace 'receiver' with member ID
      info['receiver'] = member.toString();
      item = InstantMessage.parse(info);
      if (item == null) {
        assert(false, 'failed to repack message: $member');
        continue;
      }
      res = await super.sendInstantMessage(item, priority: priority);
      if (res == null) {
        assert(false, 'failed to send message: $member');
        continue;
      }
      success += 1;
    }
    // done!
    return success;
  }

}
