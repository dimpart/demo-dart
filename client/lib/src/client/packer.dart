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

import '../dim_common.dart';
import 'facebook.dart';
import 'frequency.dart';

abstract class ClientMessagePacker extends CommonPacker {
  ClientMessagePacker(super.facebook, super.messenger);

  @override
  ClientFacebook? get facebook => super.facebook as ClientFacebook?;

  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async {
    InstantMessage? iMsg;
    try {
      iMsg = await super.decryptMessage(sMsg);
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('failed to decrypt message key')) {
        // Exception from 'SecureMessagePacker::decrypt(sMsg, receiver)'
        Log.warning('decrypt message error: $e');
        // visa.key changed?
        // push my newest visa to the sender
      } else if (errMsg.contains('receiver error')) {
        // Exception from 'MessagePacker::decryptMessage(sMsg)'
        Log.error('decrypt message error: $e');
        // not for you?
        // just ignore it
        return null;
     } else  {
        rethrow;
      }
    }
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
    CommonMessenger transceiver = messenger as CommonMessenger;
    transceiver.sendContent(command, sender: me, receiver: contact, priority: 1);
    return true;
  }

  // protected
  Future<InstantMessage?> getFailedMessage(SecureMessage sMsg) async {
    ID sender = sMsg.sender;
    ID? group = sMsg.group;
    int? type = sMsg.type;
    String? name = await facebook?.getName(sender);
    if (type == ContentType.kCommand || type == ContentType.kHistory) {
      Log.warning('ignore message unable to decrypt (type=$type) from "$name"');
      return null;
    }
    // create text content
    Content content = TextContent.create('Failed to decrypt message (type=$type) from "$name"');
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

}
