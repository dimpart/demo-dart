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

import '../../../common/protocol/app.dart';
import '../../../common/protocol/groups.dart';

import 'handler.dart';


/*  Command Transform:

    +===============================+===============================+
    |      Customized Content       |      Group Query Command      |
    +-------------------------------+-------------------------------+
    |   "type" : i2s(0xCC)          |   "type" : i2s(0x88)          |
    |   "sn"   : 123                |   "sn"   : 123                |
    |   "time" : 123.456            |   "time" : 123.456            |
    |   "app"  : "chat.dim.group"   |                               |
    |   "mod"  : "history"          |                               |
    |   "act"  : "query"            |                               |
    |                               |   "command"   : "query"       |
    |   "group"     : "{GROUP_ID}"  |   "group"     : "{GROUP_ID}"  |
    |   "last_time" : 0             |   "last_time" : 0             |
    +===============================+===============================+
 */
class GroupHistoryHandler extends BaseCustomizedContentHandler {

  @override
  Future<List<Content>> handleAction(CustomizedContent content, ReliableMessage rMsg, Messenger messenger) async {
    if (content.group == null) {
      assert(false, 'group command error: $content, sender: ${rMsg.sender}');
      String text = 'Group command error.';
      return respondReceipt(text, envelope: rMsg.envelope, content: content);
    }
    String act = content.action;
    if (act == GroupHistory.ACT_QUERY) {
      // assert(GroupHistory.APP == content.application);
      assert(GroupHistory.MOD == content.module);
      return await transformQueryCommand(content, rMsg, messenger);
    }
    assert(false, 'unknown action: $act, $content, sender: ${rMsg.sender}');
    return await super.handleAction(content, rMsg, messenger);
  }

  // private
  Future<List<Content>> transformQueryCommand(CustomizedContent content, ReliableMessage rMsg, Messenger messenger) async {
    Map info = content.copyMap(false);
    info['type'] = ContentType.COMMAND;
    info['command'] = QueryCommand.QUERY;
    Content? query = Content.parse(info);
    if (query is QueryCommand) {
      return await messenger.processContent(query, rMsg);
    }
    assert(false, 'query command error: $query, $content, sender: ${rMsg.sender}');
    String text = 'Query command error.';
    return respondReceipt(text, envelope: rMsg.envelope, content: content);
  }

}
