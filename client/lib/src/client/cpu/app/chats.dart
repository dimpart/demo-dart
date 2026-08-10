/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2026 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2026 Albert Moky
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

import '../../../common/protocol/app.dart';
import '../../../common/protocol/chats.dart';

import 'handler.dart';


abstract class ChatHistoryHandler extends BaseCustomizedContentHandler {

  @override
  Future<List<Content>> handleAction(CustomizedContent content, ReliableMessage rMsg, Messenger messenger) async {
    String act = content.action;
    if (act == SyncChatContent.ACT_SYNC) {
      InstantMessage? iMsg = InstantMessage.parse(content['message']);
      if (iMsg != null) {
        bool ok = await syncInstantMessage(iMsg, rMsg);
        assert(ok, 'failed to sync message: ${rMsg.sender}, $content');
      }
      assert(iMsg != null, 'sync message error: ${rMsg.sender}, $content');
    }
    // no need to response this action
    return [];
  }

  Future<bool> syncInstantMessage(InstantMessage iMsg, ReliableMessage rMsg) async {
    String? fromWhere = iMsg.getString('from');
    if (fromWhere == null) {
      fromWhere = rMsg.getString('from');
      if (fromWhere != null) {
        iMsg['from'] = fromWhere;
      }
      assert(fromWhere != null, 'sync message error: ${rMsg.sender}, $iMsg');
    }
    return await saveInstantMessage(iMsg);
  }

  /// Save message for myself: "chat.dim.messenger:chat_history"
  Future<bool> saveInstantMessage(InstantMessage iMsg);

}
