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

import '../dim_network.dart';

class ClientMessagePacker extends MessagePacker {
  ClientMessagePacker(super.facebook, super.messenger);

  @override
  CommonMessenger get messenger => super.messenger as CommonMessenger;

  @override
  CommonFacebook get facebook => super.facebook as CommonFacebook;

  @override
  Uint8List serializeMessage(ReliableMessage rMsg) {
    attachKeyDigest(rMsg, messenger);
    return super.serializeMessage(rMsg);
  }

  @override
  ReliableMessage? deserializeMessage(Uint8List data) {
    if (data.length < 2) {
      // message data error
      return null;
    }
    return super.deserializeMessage(data);
  }

  @override
  ReliableMessage signMessage(SecureMessage sMsg) {
    if (sMsg is ReliableMessage) {
      // already signed
      return sMsg;
    }
    return super.signMessage(sMsg);
  }

  /*
  @override
  SecureMessage encryptMessage(InstantMessage iMsg) {
    // make sure visa.key exists before encrypting message
    SecureMessage sMsg = super.encryptMessage(iMsg);
    ID receiver = iMsg.receiver;
    if (receiver.isGroup) {
      // reuse group message keys
      SymmetricKey? key = messenger?.getCipherKey(iMsg.sender, receiver);
      key?['reused'] = true;
    }
    // TODO: reuse personal message key?
    return sMsg;
  }
   */

  @override
  InstantMessage? decryptMessage(SecureMessage sMsg) {
    try {
      return super.decryptMessage(sMsg);
    } catch (e) {
      // check exception thrown by DKD: chat.dim.dkd.EncryptedMessage.decrypt()
      String errMsg = e.toString();
      if (errMsg.contains("failed to decrypt key in msg")) {
        Log.error(errMsg);
        // visa.key not updated?
        User? user = facebook.currentUser;
        Visa? visa = user?.visa;
        if (visa == null || !visa.isValid) {
          // FIXME: user visa not found?
          throw Exception('user visa error: $user');
        }
        Content content = DocumentCommand.response(user!.identifier, null, visa);
        messenger.sendContent(content, sender: user.identifier, receiver: sMsg.sender);
      } else {
        rethrow;
      }
    }
    return null;
  }

}

void attachKeyDigest(ReliableMessage rMsg, Messenger messenger) {
  // check message delegate
  rMsg.delegate ??= messenger;
  // check msg.key
  if (rMsg.containsKey("key")) {
    // getEncryptedKey() != null
    return;
  }
  // check msg.keys
  Map? keys = rMsg.encryptedKeys;
  if (keys == null) {
    keys = {};
  } else if (keys.containsKey("digest")) {
    // key digest already exists
    return;
  }
  // get key with direction
  SymmetricKey? key;
  ID sender = rMsg.sender;
  ID? group = rMsg.group;
  if (group == null) {
    ID receiver = rMsg.receiver;
    key = messenger.getCipherKey(sender, receiver, generate: false);
  } else {
    key = messenger.getCipherKey(sender, group, generate: false);
  }
  String? digest = _keyDigest(key);
  if (digest == null) {
    // broadcast message has no key
    return;
  }
  keys['digest'] = digest;
  keys['keys'] = keys;
}

String? _keyDigest(SymmetricKey? key) {
  if (key == null) {
    // key error
    return null;
  }
  Uint8List data = key.data;
  if (data.length < 6) {
    // plain key?
    return null;
  }
  // get digest for the last 6 bytes of key.data
  Uint8List part = data.sublist(data.length - 6);
  Uint8List digest = SHA256.digest(part);
  String base64 = Base64.encode(digest);
  base64 = base64.trim();
  int pos = base64.length - 8;
  return base64.substring(pos);
}
