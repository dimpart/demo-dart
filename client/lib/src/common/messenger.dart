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
import 'package:dimsdk/dimsdk.dart';

import '../dim_utils.dart';
import 'dbi/message.dart';
import 'facebook.dart';
import 'session.dart';

abstract class CommonMessenger extends Messenger implements Transmitter {
  CommonMessenger(Session session, CommonFacebook facebook, MessageDBI mdb)
      : _session = session, _facebook = facebook, _database = mdb {
    _packer = null;
    _processor = null;
  }

  final Session _session;
  final CommonFacebook _facebook;
  final MessageDBI _database;
  Packer? _packer;
  Processor? _processor;

  Session get session => _session;

  @override
  EntityDelegate get entityDelegate => _facebook;

  CommonFacebook get facebook => _facebook;

  MessageDBI get database => _database;

  @override
  CipherKeyDelegate? get cipherKeyDelegate => _database;

  @override
  Packer? get packer => _packer;
  set packer(Packer? messagePacker) => _packer = messagePacker;

  @override
  Processor? get processor => _processor;
  set processor(Processor? messageProcessor) => _processor = messageProcessor;

  ///  Request for meta with entity ID
  ///
  /// @param identifier - entity ID
  /// @return false on duplicated
  // protected
  Future<bool> queryMeta(ID identifier);

  ///  Request for meta & visa document with entity ID
  ///
  /// @param identifier - entity ID
  /// @return false on duplicated
  // protected
  Future<bool> queryDocument(ID identifier);

  ///  Request for group members with group ID
  ///
  /// @param identifier - group ID
  /// @return false on duplicated
  // protected
  Future<bool> queryMembers(ID identifier);

  ///  Add income message in a queue for waiting sender's visa
  ///
  /// @param rMsg - incoming message
  /// @param info - error info
  // protected
  void suspendReliableMessage(ReliableMessage rMsg, Map info);

  ///  Add outgo message in a queue for waiting receiver's visa
  ///
  /// @param iMsg - outgo message
  /// @param info - error info
  // protected
  void suspendInstantMessage(InstantMessage iMsg, Map info);

  /// for checking whether user's ready
  // protected
  Future<EncryptKey?> getVisaKey(ID user) async {
    EncryptKey? visaKey = await facebook.getPublicKeyForEncryption(user);
    if (visaKey != null) {
      // user is ready
      return visaKey;
    }
    // user not ready, try to query document for it
    if (await queryDocument(user)) {
      Log.info('querying document for user: $user');
    }
    return null;
  }

  /// for checking whether group's ready
  // protected
  Future<List<ID>> getMembers(ID group) async {
    Meta? meta = await facebook.getMeta(group);
    if (meta == null/* || meta.getKey() == null*/) {
      // group not ready, try to query meta for it
      if (await queryMeta(group)) {
        Log.info('querying meta for group: $group');
      }
      return [];
    }
    Group? grp = facebook.getGroup(group);
    List<ID>? members = await grp?.members;
    if (members == null || members.isEmpty) {
      // group not ready, try to query members for it
      if (await queryMembers(group)) {
        Log.info('querying members for group: $group');
      }
      return [];
    }
    // group is ready
    return members;
  }

  ///  Check sender before verifying received message
  ///
  /// @param rMsg - network message
  /// @return false on verify key not found
  // protected
  Future<bool> checkSenderInReliableMessage(ReliableMessage rMsg) async {
    ID sender = rMsg.sender;
    assert(sender.isUser, 'sender error: $sender');
    // check sender's meta & document
    Visa? visa = rMsg.visa;
    if (visa != null) {
      // first handshake?
      assert(visa.identifier == sender, 'visa ID not match: $sender');
      //assert Meta.matches(sender, rMsg.getMeta()) : "meta error: " + rMsg;
      return true;
    } else if (await getVisaKey(sender) != null) {
      // sender is OK
      return true;
    }
    // sender not ready, suspend message for waiting document
    Map<String, String> error = {
      'message': 'verify key not found',
      'user': sender.toString(),
    };
    suspendReliableMessage(rMsg, error);  // rMsg.put("error", error);
    return false;
  }

  // protected
  Future<bool> checkReceiverInSecureMessage(SecureMessage sMsg) async {
    ID receiver = sMsg.receiver;
    if (receiver.isBroadcast) {
      // broadcast message
      return true;
    } else if (receiver.isGroup) {
      // check for received group message
      List<ID> members = await getMembers(receiver);
      return members.isNotEmpty;
    }
    // the facebook will select a user from local users to match this receiver,
    // if no user matched (private key not found), this message will be ignored.
    return true;
  }

  ///  Check receiver before encrypting message
  ///
  /// @param iMsg - plain message
  /// @return false on encrypt key not found
  // protected
  Future<bool> checkReceiverInInstantMessage(InstantMessage iMsg) async {
    ID receiver = iMsg.receiver;
    if (receiver.isBroadcast) {
      // broadcast message
      return true;
    } else if (receiver.isGroup) {
      // NOTICE: station will never send group message, so
      //         we don't need to check group info here; and
      //         if a client wants to send group message,
      //         that should be sent to a group bot first,
      //         and the bot will separate it for all members.
      return false;
    } else if (await getVisaKey(receiver) != null) {
      // receiver is OK
      return true;
    }
    // receiver not ready, suspend message for waiting document
    Map<String, String> error = {
      'message': 'encrypt key not found',
      'user': receiver.toString(),
    };
    suspendInstantMessage(iMsg, error);  // iMsg.put("error", error);
    return false;
  }

  /*
  @override
  Future<Uint8List?> serializeKey(SymmetricKey password, InstantMessage iMsg) async {
    // try to reuse message key
    Object? reused = password['reused'];
    if (reused != null) {
      ID receiver = iMsg.receiver;
      if (receiver.isGroup) {
        // reuse key for grouped message
        return null;
      }
      // remove before serialize key
      password.remove("reused");
    }
    Uint8List? data = await super.serializeKey(password, iMsg);
    if (reused != null) {
      // put it back
      password['reused'] = reused;
    }
    return data;
  }
   */

  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async {
    if (await checkReceiverInInstantMessage(iMsg)) {} else {
      // receiver not ready
      String error = 'receiver not ready: ${iMsg.receiver}';
      Log.warning(error);
      throw Exception(error);
    }
    return await super.encryptMessage(iMsg);
  }

  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    if (await checkReceiverInSecureMessage(rMsg)) {} else {
      // receiver (group) not ready
      String error = 'receiver not ready: ${rMsg.receiver}';
      Log.warning(error);
      return null;
    }
    if (await checkSenderInReliableMessage(rMsg)) {} else {
      // sender not ready
      String error = 'sender not ready: ${rMsg.sender}';
      Log.warning(error);
      return null;
    }
    return await super.verifyMessage(rMsg);
  }

  //
  //  Interfaces for Transmitting Message
  //

  @override
  Future<Pair<InstantMessage, ReliableMessage?>> sendContent(Content content,
      {required ID? sender, required ID receiver, int priority = 0}) async {
    if (sender == null) {
      User? current = await facebook.currentUser;
      assert(current != null, 'current suer not set');
      sender = current!.identifier;
    }
    Envelope env = Envelope.create(sender: sender, receiver: receiver);
    InstantMessage iMsg = InstantMessage.create(env, content);
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: priority);
    return Pair(iMsg, rMsg);
  }

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    Log.debug('send instant message (type=${iMsg.content.type}): ${iMsg.sender} -> ${iMsg.receiver}');
    // send message (secured + certified) to target station
    SecureMessage? sMsg = await encryptMessage(iMsg);
    if (sMsg == null) {
      // assert(false, 'public key not found?');
      return null;
    }
    ReliableMessage? rMsg = await signMessage(sMsg);
    if (rMsg == null) {
      // TODO: set msg.state = error
      throw Exception('failed to sign message: ${sMsg.dictionary}');
    }
    if (await sendReliableMessage(rMsg, priority: priority)) {
      return rMsg;
    } else {
      // failed
      return null;
    }
  }

  @override
  Future<bool> sendReliableMessage(ReliableMessage rMsg, {int priority = 0}) async {
    // 1. serialize message
    Uint8List? data = await serializeMessage(rMsg);
    if (data == null) {
      assert(false, 'failed to serialize message: ${rMsg.dictionary}');
      return false;
    }
    // 2. call gate keeper to send the message data package
    //    put message package into the waiting queue of current session
    return session.queueMessagePackage(rMsg, data, priority: priority);
  }

}
