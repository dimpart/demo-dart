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
import 'facebook.dart';
import 'frequency.dart';

class ClientMessagePacker extends CommonPacker {
  ClientMessagePacker(super.facebook, super.messenger);

  @override
  ClientFacebook? get facebook => super.facebook as ClientFacebook?;

  @override
  Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async {
    await attachKeyDigest(rMsg, messenger!);
    return await super.serializeMessage(rMsg);
  }

  @override
  Future<ReliableMessage?> deserializeMessage(Uint8List data) async {
    if (data.length < 2) {
      // message data error
      return null;
    }
    return await super.deserializeMessage(data);
  }

  @override
  Future<ReliableMessage?> signMessage(SecureMessage sMsg) async {
    if (sMsg is ReliableMessage) {
      // already signed
      return sMsg;
    }
    return await super.signMessage(sMsg);
  }

  /*
  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async {
    // make sure visa.key exists before encrypting message
    SecureMessage? sMsg = await super.encryptMessage(iMsg);
    ID receiver = iMsg.receiver;
    if (receiver.isGroup) {
      // reuse group message keys
      SymmetricKey? key = await messenger.getCipherKey(iMsg.sender, receiver);
      key?['reused'] = true;
    }
    // TODO: reuse personal message key?
    return sMsg;
  }
   */

  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async {
    InstantMessage? iMsg = await super.decryptMessage(sMsg);
    if (iMsg == null) {
      // failed to decrypt message, visa.key changed?
      // 1. push new visa document to this message sender
      pushVisa(sMsg.sender);
      // 2. build 'failed' message
      iMsg = await getFailedMessage(sMsg);
    }
    return iMsg;
  }

  // protected
  Future<bool> pushVisa(ID contact) async {
    QueryFrequencyChecker checker = QueryFrequencyChecker();
    if (!checker.isDocumentResponseExpired(contact, force: false)) {
      // response not expired yet
      Log.debug('visa response not expired yet: $contact');
      return false;
    }
    Log.info('push visa to: $contact');
    User? user = await facebook?.currentUser;
    Visa? visa = await user?.visa;
    if (visa == null || !visa.isValid) {
      // FIXME: user visa not found?
      assert(false, 'user visa error: $user');
      return false;
    }
    ID me = user!.identifier;
    DocumentCommand command = DocumentCommand.response(me, null, visa);
    messenger?.sendContent(command, sender: me, receiver: contact, priority: 1);
    return true;
  }

  // protected
  Future<InstantMessage?> getFailedMessage(SecureMessage sMsg) async {
    ID sender = sMsg.sender;
    ID? group = sMsg.group;
    String? name = await facebook?.getName(sender);
    // create text content
    Content content = TextContent.create('Failed to decrypt message from: $name');
    content.group = group;
    // pack instant message
    Map info = sMsg.copyMap(false);
    info.remove('data');
    info['content'] = content.toMap();
    return InstantMessage.parse(info);
  }

  @override
  Future<bool> checkReceiverInInstantMessage(InstantMessage iMsg) async {
    ID receiver = iMsg.receiver;
    if (receiver.isBroadcast) {
      // broadcast message
      return true;
    } else if (receiver.isUser) {
      // check user's meta & document
      return await super.checkReceiverInInstantMessage(iMsg);
    }
    //
    //  check group's meta & members
    //
    List<ID> members = await getMembers(receiver);
    if (members.isEmpty) {
      // group not ready, suspend message for waiting meta/members
      Map<String, String> error = {
        'message': 'group not found',
        'group': receiver.toString(),
      };
      suspendInstantMessage(iMsg, error);  // iMsg.put("error", error);
      return false;
    }
    //
    //  check group members' visa key
    //
    List<ID> waiting = [];
    for (ID item in members) {
      if (await getVisaKey(item) == null) {
        // member not ready
        waiting.add(item);
      }
    }
    if (waiting.isEmpty) {
      // all members' visa keys exist
      return true;
    }
    // members not ready, suspend message for waiting document
    Map<String, Object> error = {
      'message': 'members not ready',
      'group': receiver.toString(),
      'members': ID.revert(waiting),
    };
    suspendInstantMessage(iMsg, error);  // iMsg.put("error", error);
    return false;
  }

  @override
  void suspendInstantMessage(InstantMessage iMsg, Map info) {
    // TODO:
  }

  @override
  void suspendReliableMessage(ReliableMessage rMsg, Map info) {
    // TODO:
  }

}

Future<void> attachKeyDigest(ReliableMessage rMsg, Messenger messenger) async {
  // check msg.key
  if (rMsg['key'] != null) {
    // getEncryptedKey() != null
    return;
  }
  // check msg.keys
  Map? keys = await rMsg.encryptedKeys;
  if (keys == null) {
    keys = {};
  } else if (keys['digest'] != null) {
    // key digest already exists
    return;
  }
  // get key with direction
  ID sender = rMsg.sender;
  ID receiver = rMsg.receiver;
  ID? group = rMsg.group;
  ID target = CipherKeyDelegate.getDestination(receiver: receiver, group: group);
  SymmetricKey? key = await messenger.getCipherKey(sender: sender, receiver: target, generate: false);
  String? digest = _keyDigest(key);
  if (digest == null) {
    // broadcast message has no key
    return;
  }
  keys['digest'] = digest;
  rMsg['keys'] = keys;
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
