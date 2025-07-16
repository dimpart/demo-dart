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

import '../../common/protocol/customized.dart';
import '../../common/protocol/groups.dart';


///  Handler for Customized Content
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
abstract interface class CustomizedContentHandler {

  ///  Do your job
  ///
  /// @param act     - action
  /// @param sender  - user ID
  /// @param content - customized content
  /// @param rMsg    - network message
  /// @return responses
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content, ReliableMessage rMsg);

}


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
class _GroupHistoryHandler extends TwinsHelper implements CustomizedContentHandler {
  _GroupHistoryHandler(super.facebook, super.messenger);

  @override
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content, ReliableMessage rMsg) async {
    var transceiver = messenger;
    if (transceiver == null) {
      assert(false, 'messenger lost');
      return [];
    } else if (act == GroupHistory.ACT_QUERY) {
      assert(GroupHistory.APP == content.application);
      assert(GroupHistory.MOD == content.module);
      assert(content.group != null, 'group command error: $content, sender: $sender');
    } else {
      assert(false, 'unknown action: $act, $content, sender: $sender');
      return [];
    }
    Map info = content.copyMap(false);
    info['type'] = ContentType.COMMAND;
    info['command'] = GroupCommand.QUERY;
    Content? query = Content.parse(info);
    if (query is QueryCommand) {
      return await transceiver.processContent(query, rMsg);
    }
    assert(false, 'query command error: $query, $content, sender: $sender');
    return [];
  }

}


///  Customized Content Processing Unit
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class CustomizedContentProcessor extends BaseContentProcessor implements CustomizedContentHandler {
  CustomizedContentProcessor(Facebook facebook, Messenger messenger) : super(facebook, messenger) {
    _groupHistoryHandler = _GroupHistoryHandler(facebook, messenger);
  }

  late final _GroupHistoryHandler _groupHistoryHandler;

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is CustomizedContent, 'customized content error: $content');
    CustomizedContent customized = content as CustomizedContent;
    // 1. check app id
    String app = customized.application;
    List<Content>? res = filter(app, content, rMsg);
    if (res != null) {
      // app id not found
      return res;
    }
    // 2. get handler with module name
    String mod = customized.module;
    CustomizedContentHandler? handler = fetch(mod, customized, rMsg);
    if (handler == null) {
      // module not support
      return [];
    }
    // 3. do the job
    String act = customized.action;
    ID sender = rMsg.sender;
    return await handler.handleAction(act, sender, customized, rMsg);
  }

  /// override for your application
  // protected
  List<Content>? filter(String app, CustomizedContent content, ReliableMessage rMsg) {
    if (app == GroupHistory.APP) {
      // app id matched,
      // return no errors
      return null;
    }
    String text = 'Content not support.';
    return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'Customized content (app: \${app}) not support yet!',
      'replacements': {
        'app': app,
      }
    });
  }

  /// override for your modules
  // protected
  CustomizedContentHandler? fetch(String mod, CustomizedContent content, ReliableMessage rMsg) {
    if (mod == GroupHistory.MOD) {
      String app = content.application;
      if (app == GroupHistory.APP) {
        return _groupHistoryHandler;
      }
      assert(false, 'unknown app: $app, content: $content, sender: ${rMsg.sender}');
      // return null;
    }
    // if the application has too many modules, I suggest you to
    // use different handler to do the jobs for each module.
    return this;
  }

  /// override for customized actions
  @override
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content, ReliableMessage rMsg) async {
    String app = content.application;
    String mod = content.module;
    String text = 'Content not support.';
    return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'Customized content (app: \${app}, mod: \${mod}, act: \${act}) not support yet!',
      'replacements': {
        'app': app,
        'mod': mod,
        'act': act,
      }
    });
  }

}
