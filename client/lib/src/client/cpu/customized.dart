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

import '../../common/protocol/groups.dart';


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
class GroupHistoryHandler extends BaseCustomizedHandler {
  GroupHistoryHandler(super.facebook, super.messenger);

  @override
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content, ReliableMessage rMsg) async {
    if (content.group == null) {
      assert(false, 'group command error: $content, sender: $sender');
      String text = 'Group command error.';
      return respondReceipt(text, envelope: rMsg.envelope, content: content);
    } else if (GroupHistory.ACT_QUERY == act) {
      assert(GroupHistory.APP == content.application);
      assert(GroupHistory.MOD == content.module);
      return await transformQueryCommand(content, rMsg);
    }
    assert(false, 'unknown action: $act, $content, sender: $sender');
    return await super.handleAction(act, sender, content, rMsg);
  }

  // private
  Future<List<Content>> transformQueryCommand(CustomizedContent content, ReliableMessage rMsg) async {
    var transceiver = messenger;
    if (transceiver == null) {
      assert(false, 'messenger lost');
      return [];
    }
    Map info = content.copyMap(false);
    info['type'] = ContentType.COMMAND;
    info['command'] = GroupCommand.QUERY;
    Content? query = Content.parse(info);
    if (query is QueryCommand) {
      return await transceiver.processContent(query, rMsg);
    }
    assert(false, 'query command error: $query, $content, sender: ${rMsg.sender}');
    String text = 'Query command error.';
    return respondReceipt(text, envelope: rMsg.envelope, content: content);
  }

}


///  Customized Content Processing Unit
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///  Handle content for application customized
class AppCustomizedProcessor extends CustomizedContentProcessor {
  AppCustomizedProcessor(super.facebook, super.messenger);

  final Map<String, CustomizedContentHandler> _handlers = {};

  void setHandler({
    required String app, required String mod,
    required CustomizedContentHandler handler
  }) => _handlers['$app:$mod'] = handler;

  // private
  CustomizedContentHandler? getHandler({
    required String app, required String mod
  }) => _handlers['$app:$mod'];

  /// override for your modules
  @override
  CustomizedContentHandler filter(String app, String mod, CustomizedContent content, ReliableMessage rMsg) {
    CustomizedContentHandler? handler = getHandler(app: app, mod: mod);
    if (handler != null) {
      return handler;
    }
    // default handler
    return super.filter(app, mod, content, rMsg);
  }

}
