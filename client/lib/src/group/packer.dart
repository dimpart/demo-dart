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
import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/lnc.dart';

import 'delegate.dart';

class GroupPacker {
  GroupPacker(this.delegate);

  // protected
  final GroupDelegate delegate;

  // protected
  Messenger? get messenger => delegate.messenger;

  ///  Pack as broadcast message
  Future<ReliableMessage?> packMessage(Content content, {required ID sender}) async {
    Envelope envelope = Envelope.create(sender: sender, receiver: ID.kAnyone);
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    iMsg.setString('group', content.group);  // expose group ID
    return await encryptAndSignMessage(iMsg);
  }

  Future<ReliableMessage?> encryptAndSignMessage(InstantMessage iMsg) async {
    Messenger? transceiver = messenger;
    // encrypt for receiver
    SecureMessage? sMsg = await transceiver?.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message: ${iMsg.sender} => ${iMsg.receiver}, ${iMsg.group}');
      return null;
    }
    // sign for sender
    ReliableMessage? rMsg = await transceiver?.signMessage(sMsg);
    if (rMsg == null) {
      assert(false, 'failed to sign message: ${iMsg.sender} => ${iMsg.receiver}, ${iMsg.group}');
      return null;
    }
    // OK
    return rMsg;
  }

  Future<List<InstantMessage>> splitInstantMessage(InstantMessage iMsg, List<ID> allMembers) async {
    List<InstantMessage> messages = [];
    ID sender = iMsg.sender;

    Map info;
    InstantMessage? item;
    for (ID receiver in allMembers) {
      if (sender == receiver) {
        Log.info('skip cycled message: $receiver, ${iMsg.group}');
        continue;
      }
      Log.info('split group message for member: $receiver');
      info = iMsg.copyMap(false);
      // replace 'receiver' with member ID
      info['receiver'] = receiver.toString();
      item = InstantMessage.parse(info);
      if (item == null) {
        assert(false, 'failed to repack message: $receiver');
        continue;
      }
      messages.add(item);
    }

    return messages;
  }

  Future<List<ReliableMessage>> splitReliableMessage(ReliableMessage rMsg, List<ID> allMembers) async {
    List<ReliableMessage> messages = [];
    ID sender = rMsg.sender;

    assert(!rMsg.containsKey('key'), 'should not happen');
    Map? keys = await rMsg.encryptedKeys;
    keys ??= {};  // TODO: get key digest

    Object? keyData;  // Base-64
    Map info;
    ReliableMessage? item;
    for (ID receiver in allMembers) {
      if (sender == receiver) {
        Log.info('skip cycled message: $receiver, ${rMsg.group}');
        continue;
      }
      Log.info('split group message for member: $receiver');
      info = rMsg.copyMap(false);
      // replace 'receiver' with member ID
      info['receiver'] = receiver.toString();
      // fetch encrypted key data
      info.remove('keys');
      keyData = keys[receiver.toString()];
      if (keyData != null) {
        info['key'] = keyData;
      }
      item = ReliableMessage.parse(info);
      if (item == null) {
        assert(false, 'failed to repack message: $receiver');
        continue;
      }
      messages.add(item);
    }

    return messages;
  }

}
