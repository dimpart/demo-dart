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

abstract class ClientMessagePacker extends CommonPacker {
  ClientMessagePacker(super.facebook, super.messenger);

  @override
  ClientFacebook? get facebook => super.facebook as ClientFacebook?;

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
