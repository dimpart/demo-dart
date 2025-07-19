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
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content,
      ReliableMessage rMsg);

}

/// Default Handler
/// ~~~~~~~~~~~~~~~
class BaseCustomizedHandler extends TwinsHelper implements CustomizedContentHandler {
  BaseCustomizedHandler(super.facebook, super.messenger);

  @override
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content,
      ReliableMessage rMsg) async {
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

  //
  //  Convenient responding
  //

  // protected
  List<ReceiptCommand> respondReceipt(String text, {
    required Envelope envelope, Content? content, Map<String, Object>? extra
  }) => [
    // create base receipt command with text & original envelope
    BaseContentProcessor.createReceipt(text, envelope: envelope, content: content, extra: extra)
  ];

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
class GroupHistoryHandler extends BaseCustomizedHandler {
  GroupHistoryHandler(super.facebook, super.messenger);

  bool matches(String app, String mod) => app == GroupHistory.APP && mod == GroupHistory.MOD;

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
      return await super.handleAction(act, sender, content, rMsg);
    }
    Map info = content.copyMap(false);
    info['type'] = ContentType.COMMAND;
    info['command'] = GroupCommand.QUERY;
    Content? query = Content.parse(info);
    if (query is QueryCommand) {
      return await transceiver.processContent(query, rMsg);
    }
    assert(false, 'query command error: $query, $content, sender: $sender');
    String text = 'Query command error.';
    return respondReceipt(text, envelope: rMsg.envelope, content: content);
  }

}


///  Customized Content Processing Unit
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///  Handle content for application customized
class CustomizedContentProcessor extends BaseContentProcessor {
  CustomizedContentProcessor(Facebook facebook, Messenger messenger) : super(facebook, messenger) {
    defaultHandler = createDefaultHandler(facebook, messenger);
    groupHistoryHandler = createGroupHistoryHandler(facebook, messenger);
  }

  // protected
  CustomizedContentHandler createDefaultHandler(Facebook facebook, Messenger messenger) =>
      BaseCustomizedHandler(facebook, messenger);
  // protected
  GroupHistoryHandler createGroupHistoryHandler(Facebook facebook, Messenger messenger) =>
      GroupHistoryHandler(facebook, messenger);

  // protected
  late final CustomizedContentHandler defaultHandler;
  // protected
  late final GroupHistoryHandler groupHistoryHandler;

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is CustomizedContent, 'customized content error: $content');
    CustomizedContent customized = content as CustomizedContent;
    // get handler for 'app' & 'mod'
    String app = customized.application;
    String mod = customized.module;
    CustomizedContentHandler? handler = filter(app, mod, customized, rMsg);
    handler ??= defaultHandler;
    // handle the action
    String act = customized.action;
    ID sender = rMsg.sender;
    return await handler.handleAction(act, sender, customized, rMsg);
  }

  /// override for your modules
  // protected
  CustomizedContentHandler? filter(String app, String mod, CustomizedContent content, ReliableMessage rMsg) {
    if (content.group != null) {
      if (groupHistoryHandler.matches(app, mod)) {
        return groupHistoryHandler;
      }
    }
    assert(false, 'unknown app: $app, mod: $mod, content: $content, sender: ${rMsg.sender}');
    // if the application has too many modules, I suggest you to
    // use different handler to do the jobs for each module.
    return null;
  }

}
