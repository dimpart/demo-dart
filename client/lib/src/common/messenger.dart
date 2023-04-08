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

import 'dbi/message.dart';
import 'facebook.dart';
import 'session.dart';
import 'utils/log.dart';
import 'utils/tuples.dart';

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
  bool queryMeta(ID identifier);

  ///  Request for meta & visa document with entity ID
  ///
  /// @param identifier - entity ID
  /// @return false on duplicated
  // protected
  bool queryDocument(ID identifier);

  ///  Request for group members with group ID
  ///
  /// @param identifier - group ID
  /// @return false on duplicated
  // protected
  bool queryMembers(ID identifier);

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
  EncryptKey? getVisaKey(ID user) {
    EncryptKey? visaKey = facebook.getPublicKeyForEncryption(user);
    if (visaKey != null) {
      // user is ready
      return visaKey;
    }
    // user not ready, try to query document for it
    if (queryDocument(user)) {
      Log.info('querying document for user: $user');
    }
    return null;
  }

  /// for checking whether group's ready
  // protected
  List<ID> getMembers(ID group) {
    Meta? meta = facebook.getMeta(group);
    if (meta == null/* || meta.getKey() == null*/) {
      // group not ready, try to query meta for it
      if (queryMeta(group)) {
        Log.info('querying meta for group: $group');
      }
      return [];
    }
    Group? grp = facebook.getGroup(group);
    List<ID>? members = grp?.members;
    if (members == null || members.isEmpty) {
      // group not ready, try to query members for it
      if (queryMembers(group)) {
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
  bool checkSenderInReliableMessage(ReliableMessage rMsg) {
    ID sender = rMsg.sender;
    assert(sender.isUser, 'sender error: $sender');
    // check sender's meta & document
    Visa? visa = rMsg.visa;
    if (visa != null) {
      // first handshake?
      assert(visa.identifier == sender, 'visa ID not match: $sender');
      //assert Meta.matches(sender, rMsg.getMeta()) : "meta error: " + rMsg;
      return true;
    } else if (getVisaKey(sender) != null) {
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
  bool checkReceiverInSecureMessage(SecureMessage sMsg) {
    ID receiver = sMsg.receiver;
    if (receiver.isBroadcast) {
      // broadcast message
      return true;
    } else if (receiver.isGroup) {
      // check for received group message
      List<ID> members = getMembers(receiver);
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
  bool checkReceiverInInstantMessage(InstantMessage iMsg) {
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
    } else if (getVisaKey(receiver) != null) {
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
  Uint8List? serializeKey(SymmetricKey password, InstantMessage iMsg) {
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
    Uint8List? data = super.serializeKey(password, iMsg);
    if (reused != null) {
      // put it back
      password['reused'] = reused;
    }
    return data;
  }
   */

  @override
  SecureMessage encryptMessage(InstantMessage iMsg) {
    if (!checkReceiverInInstantMessage(iMsg)) {
      // receiver not ready
      String error = 'receiver not ready: ${iMsg.receiver}';
      Log.warning(error);
      throw Exception(error);
    }
    return super.encryptMessage(iMsg);
  }

  @override
  SecureMessage? verifyMessage(ReliableMessage rMsg) {
    if (!checkReceiverInSecureMessage(rMsg)) {
      // receiver (group) not ready
      String error = 'receiver not ready: ${rMsg.receiver}';
      Log.warning(error);
      return null;
    }
    if (!checkSenderInReliableMessage(rMsg)) {
      // sender not ready
      String error = 'sender not ready: ${rMsg.sender}';
      Log.warning(error);
      return null;
    }
    return super.verifyMessage(rMsg);
  }

  //
  //  Interfaces for Transmitting Message
  //

  @override
  Pair<InstantMessage, ReliableMessage?> sendContent(ID? sender, ID receiver, Content content, int priority) {
    if (sender == null) {
      User? current = facebook.currentUser;
      assert(current != null, 'current suer not set');
      sender = current!.identifier;
    }
    Envelope env = Envelope.create(sender: sender, receiver: receiver);
    InstantMessage iMsg = InstantMessage.create(env, content);
    ReliableMessage? rMsg = sendInstantMessage(iMsg, priority);
    return Pair(iMsg, rMsg);
  }

  @override
  ReliableMessage? sendInstantMessage(InstantMessage iMsg, int priority) {
    Log.debug('send instant message (type=${iMsg.content.type}): ${iMsg.sender} -> ${iMsg.receiver}');
    // send message (secured + certified) to target station
    SecureMessage sMsg = encryptMessage(iMsg);
    if (sMsg.isEmpty) {
      assert(false, 'public key not found?');
      return null;
    }
    ReliableMessage rMsg = signMessage(sMsg);
    if (rMsg.isEmpty) {
      // TODO: set msg.state = error
      throw Exception('failed to sign message: ${sMsg.dictionary}');
    }
    if (sendReliableMessage(rMsg, priority)) {
      return rMsg;
    } else {
      // failed
      return null;
    }
  }

  @override
  bool sendReliableMessage(ReliableMessage rMsg, int priority) {
    // 1. serialize message
    Uint8List data = serializeMessage(rMsg);
    assert(data.isNotEmpty, 'failed to serialize message: ${rMsg.dictionary}');
    // 2. call gate keeper to send the message data package
    //    put message package into the waiting queue of current session
    return session.queueMessagePackage(rMsg, data, priority);
  }

}
