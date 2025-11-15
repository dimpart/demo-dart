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
import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/log.dart';


abstract class CommonPacker extends MessagePacker with Logging {
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

  //
  //  Checking
  //

  /// for checking whether user's ready
  // protected
  Future<EncryptKey?> getMessageKey(ID user) async =>
      await facebook?.getPublicKeyForEncryption(user);

  ///  Check sender before verifying received message
  ///
  /// @param rMsg - network message
  /// @return false on verify key not found
  // protected
  Future<bool> checkSender(ReliableMessage rMsg) async {
    ID sender = rMsg.sender;
    assert(sender.isUser, 'sender error: $sender');
    // check sender's meta & document
    Visa? visa = MessageUtils.getVisa(rMsg);
    if (visa != null) {
      // first handshake?
      bool matched = visa.identifier == sender;
      //assert Meta.matches(sender, rMsg.getMeta()) : "meta error: " + rMsg;
      assert(matched, 'visa ID not match: $sender');
      return matched;
    } else if (await getMessageKey(sender) != null) {
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

  ///  Check receiver before encrypting message
  ///
  /// @param iMsg - plain message
  /// @return false on encrypt key not found
  // protected
  Future<bool> checkReceiver(InstantMessage iMsg) async {
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
    } else if (await getMessageKey(receiver) != null) {
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

  //
  //  Packing
  //

  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async {
    // make sure visa.key exists before encrypting message

    //
    //  Check FileContent
    //  ~~~~~~~~~~~~~~~~~
    //  You must upload file data before packing message.
    //
    Content content = iMsg.content;
    if (content is FileContent && content.data != null) {
      ID sender = iMsg.sender;
      ID receiver = iMsg.receiver;
      ID? group = iMsg.group;
      var error = 'You should upload file data before calling '
          'sendInstantMessage: $sender -> $receiver ($group)';
      logError(error);
      assert(false, error);
      return null;
    }

    // the intermediate node(s) can only get the message's signature,
    // but cannot know the 'sn' because it cannot decrypt the content,
    // this is usually not a problem;
    // but sometimes we want to respond a receipt with original sn,
    // so I suggest to expose 'sn' here.
    iMsg['sn'] = content.sn;

    // 1. check contact info
    // 2. check group members info
    if (await checkReceiver(iMsg)) {
      // receiver is ready
    } else {
      logWarning('receiver not ready: ${iMsg.receiver}');
      return null;
    }
    return await super.encryptMessage(iMsg);
  }

  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    // 1. check receiver/group with local user
    // 2. check sender's visa info
    if (await checkSender(rMsg)) {
      // sender is ready
    } else {
      logWarning('sender not ready: ${rMsg.sender}');
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

  // @override
  // Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async {
  //   SymmetricKey? key = await messenger?.getDecryptKey(rMsg);
  //   assert(key != null, 'encrypt key should not empty here');
  //   String? digest = _getKeyDigest(key);
  //   if (digest != null) {
  //     bool reused = key!.getBool('reused') ?? false;
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
//   String? value = key.getString('digest');
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
