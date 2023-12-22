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
import 'package:lnc/lnc.dart';

import 'compat/compatible.dart';

abstract class CommonPacker extends MessagePacker {
  CommonPacker(super.facebook, super.messenger);

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
  Future<EncryptKey?> getVisaKey(ID user) async =>
      await facebook?.getPublicKeyForEncryption(user);

  /// for checking whether group's ready
  // protected
  Future<List<ID>> getMembers(ID group) async =>
      await facebook!.getMembers(group);

  ///  Check sender before verifying received message
  ///
  /// @param rMsg - network message
  /// @return false on verify key not found
  // protected
  Future<bool> checkSenderInReliableMessage(ReliableMessage rMsg) async {
    ID sender = rMsg.sender;
    assert(sender.isUser, 'sender error: $sender');
    // check sender's meta & document
    Visa? visa = MessageHelper.getVisa(rMsg);
    if (visa != null) {
      // first handshake?
      assert(visa.identifier == sender, 'visa ID not match: $sender');
      //assert Meta.matches(sender, rMsg.getMeta()) : "meta error: " + rMsg;
      return visa.identifier == sender;
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
  Future<bool> checkReceiverInReliableMessage(ReliableMessage sMsg) async {
    ID receiver = sMsg.receiver;
    // check group
    ID? group = ID.parse(sMsg['group']);
    if (group == null && receiver.isGroup) {
      /// Transform:
      ///     (B) => (J)
      ///     (D) => (G)
      group = receiver;
    }
    if (group == null || group.isBroadcast) {
      /// A, C - personal message (or hidden group message)
      //      the packer will call the facebook to select a user from local
      //      for this receiver, if no user matched (private key not found),
      //      this message will be ignored;
      /// E, F, G - broadcast group message
      //      broadcast message is not encrypted, so it can be read by anyone.
      return true;
    }
    /// H, J, K - group message
    //      check for received group message
    List<ID> members = await getMembers(group);
    if (members.isNotEmpty) {
      // group is ready
      return true;
    }
    // group not ready, suspend message for waiting members
    Map<String, String> error = {
      'message': 'group not ready',
      'group': group.toString(),
    };
    suspendReliableMessage(sMsg, error);  // rMsg.put("error", error);
    return false;
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
      //         and the bot will split it for all members.
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

  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async {
    // 1. check contact info
    // 2. check group members info
    if (await checkReceiverInInstantMessage(iMsg)) {
      // receiver is ready
    } else {
      Log.warning('receiver not ready: ${iMsg.receiver}');
      return null;
    }
    return await super.encryptMessage(iMsg);
  }

  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    // 1. check sender's meta
    if (await checkSenderInReliableMessage(rMsg)) {
      // sender is ready
    } else {
      Log.warning('sender not ready: ${rMsg.sender}');
      return null;
    }
    // 2. check receiver/group with local user
    if (await checkReceiverInReliableMessage(rMsg)) {
      // receiver is ready
    } else {
      // receiver (group) not ready
      Log.warning('receiver not ready: ${rMsg.receiver}');
      return null;
    }
    return await super.verifyMessage(rMsg);
  }

  @override
  Future<ReliableMessage?> signMessage(SecureMessage sMsg) async {
    if (sMsg is ReliableMessage) {
      // already signed
      return sMsg;
    }
    return await super.signMessage(sMsg);
  }

  @override
  Future<ReliableMessage?> deserializeMessage(Uint8List data) async {
    if (data.length <= 4) {
      // message data error
      return null;
    // } else if (data.first != '{'.codeUnitAt(0) || data.last != '}'.codeUnitAt(0)) {
    //   // only support JsON format now
    //   return null;
    }
    ReliableMessage? rMsg = await super.deserializeMessage(data);
    if (rMsg != null) {
      Compatible.fixMetaAttachment(rMsg);
    }
    return rMsg;
  }

  @override
  Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async {
    Compatible.fixMetaAttachment(rMsg);
    return await super.serializeMessage(rMsg);
  }

  // @override
  // Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async {
  //   SymmetricKey? key = await messenger?.getDecryptKey(rMsg);
  //   assert(key != null, 'encrypt key should not empty here');
  //   String? digest = _getKeyDigest(key);
  //   if (digest != null) {
  //     bool reused = key!.getBool('reused', false)!;
  //     if (reused) {
  //       // replace key/keys with key digest
  //       Map keys = {
  //         'digest': digest,
  //       };
  //       rMsg['keys'] = keys;
  //       rMsg.remove('key');
  //     } else {
  //       // reuse it next time
  //       key['reused'] = true;
  //     }
  //   }
  //   return await super.serializeMessage(rMsg);
  // }

}

// String? _getKeyDigest(SymmetricKey? key) {
//   if (key == null) {
//     // key error
//     return null;
//   }
//   String? value = key.getString('digest', null);
//   if (value != null) {
//     return value;
//   }
//   Uint8List data = key.data;
//   if (data.length < 6) {
//     // plain key?
//     return null;
//   }
//   // get digest for the last 6 bytes of key.data
//   Uint8List part = data.sublist(data.length - 6);
//   Uint8List digest = SHA256.digest(part);
//   String base64 = Base64.encode(digest);
//   base64 = base64.trim();
//   int pos = base64.length - 8;
//   value = base64.substring(pos);
//   key['digest'] = value;
//   return value;
// }
