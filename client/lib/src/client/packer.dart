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

import '../common/packer.dart';

import 'facebook.dart';
import 'messenger.dart';

abstract class ClientMessagePacker extends CommonPacker {
  ClientMessagePacker(super.facebook, super.messenger);

  @override
  ClientFacebook? get facebook => super.facebook as ClientFacebook?;

  @override
  Future<bool> checkReceiver(InstantMessage iMsg) async {
    ID receiver = iMsg.receiver;
    if (receiver.isBroadcast) {
      // broadcast message
      return true;
    } else if (receiver.isUser) {
      // check user's meta & document
      return await super.checkReceiver(iMsg);
    }
    //
    //  check group's meta & members
    //
    List<ID> members = await getMembers(receiver);
    if (members.isEmpty) {
      // group not ready, suspend message for waiting meta/members
      Map<String, String> error = {
        'message': 'group members not found',
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
    // perhaps some members have already disappeared,
    // although the packer will query document when the member's visa key is not found,
    // but the station will never respond with the right document,
    // so we must return true here to let the messaging continue;
    // when the member's visa is responded, we should send the suspended message again.
    return waiting.length < members.length;
  }

  // protected
  Future<bool> checkGroup(ReliableMessage sMsg) async {
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

  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    // check receiver/group with local user
    if (await checkGroup(rMsg)) {
      // receiver is ready
    } else {
      // receiver (group) not ready
      logWarning('receiver not ready: ${rMsg.receiver}');
      return null;
    }
    return await super.verifyMessage(rMsg);
  }

  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async {
    InstantMessage? iMsg;
    try {
      iMsg = await super.decryptMessage(sMsg);
    } catch (e, st) {
      String errMsg = e.toString();
      if (errMsg.contains('failed to decrypt message key')) {
        // Exception from 'SecureMessagePacker::decrypt(sMsg, receiver)'
        logWarning('decrypt message error: $e, $st');
        // visa.key changed?
        // push my newest visa to the sender
      } else if (errMsg.contains('receiver error')) {
        // Exception from 'MessagePacker::decryptMessage(sMsg)'
        logError('decrypt message error: $e, $st');
        // not for you?
        // just ignore it
        return null;
      } else {
        rethrow;
      }
    }
    if (iMsg == null) {
      // failed to decrypt message, visa.key changed?
      // 1. push new visa document to this message sender
      /*await */pushVisa(sMsg.sender);
      // 2. build 'failed' message
      iMsg = await getFailedMessage(sMsg);
    } else {
      Content content = iMsg.content;
      if (content is FileContent) {
        if (content.password == null && content.url != null) {
          // now received file content with remote data,
          // which must be encrypted before upload to CDN;
          // so keep the password here for decrypting after downloaded.
          SymmetricKey? key = await messenger?.getDecryptKey(sMsg);
          assert(key != null, 'failed to get msg key: '
              '${sMsg.sender} => ${sMsg.receiver}, ${sMsg['group']}');
          // keep password to decrypt data after downloaded
          content.password = key;
        }
      }
    }
    return iMsg;
  }

  // protected
  Future<bool> pushVisa(ID contact) async {
    // visa.key not updated?
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    Visa? visa = await user.visa;
    if (visa == null || !visa.isValid) {
      // FIXME: user visa not found?
      throw Exception('user visa error: $user');
    }
    var transceiver = messenger;
    if (transceiver is! ClientMessenger) {
      assert(false, 'messenger error: $transceiver');
      return false;
    }
    return await transceiver.sendVisa(visa, contact);
  }

  // protected
  Future<InstantMessage?> getFailedMessage(SecureMessage sMsg) async {
    ID sender = sMsg.sender;
    ID? group = sMsg.group;
    int? type = sMsg.type;
    if (type == ContentType.kCommand || type == ContentType.kHistory) {
      logWarning('ignore message unable to decrypt (type=$type) from "$sender"');
      return null;
    }
    // create text content
    Content content = TextContent.create('Failed to decrypt message.');
    content.addAll({
      'template': 'Failed to decrypt message (type=\${type}) from "\${sender}".',
      'replacements': {
        'type': type,
        'sender': sender.toString(),
        'group': group?.toString(),
      }
    });
    if (group != null) {
      content.group = group;
    }
    // pack instant message
    Map info = sMsg.copyMap(false);
    info.remove('data');
    info['content'] = content.toMap();
    return InstantMessage.parse(info);
  }

}
