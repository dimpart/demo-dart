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

import '../../common/protocol/ans.dart';
import '../../common/protocol/groups.dart';
import '../../common/protocol/handshake.dart';
import '../../common/protocol/login.dart';

import 'commands.dart';
import 'group.dart';
import 'group/expel.dart';
import 'group/invite.dart';
import 'group/join.dart';
import 'group/query.dart';
import 'group/quit.dart';
import 'group/reset.dart';
import 'group/resign.dart';
import 'handshake.dart';
import 'customized.dart';


class ClientContentProcessorCreator extends BaseContentProcessorCreator {
  ClientContentProcessorCreator(super.facebook, super.messenger);
  
  // protected
  AppCustomizedProcessor createCustomizedContentProcessor(Facebook facebook, Messenger messenger) {
    var cpu = AppCustomizedProcessor(facebook, messenger);

    // 'chat.dim.group:history'
    cpu.setHandler(
      app: GroupHistory.APP,
      mod: GroupHistory.MOD,
      handler: GroupHistoryHandler(facebook, messenger),
    );

    return cpu;
  }

  @override
  ContentProcessor? createContentProcessor(String msgType) {
    switch (msgType) {

      // application customized
      case ContentType.APPLICATION:
      case 'application':
      case ContentType.CUSTOMIZED:
      case 'customized':
        return createCustomizedContentProcessor(facebook!, messenger!);

      // history command
      case ContentType.HISTORY:
      case 'history':
        return HistoryCommandProcessor(facebook!, messenger!);

    }
    // others
    return super.createContentProcessor(msgType);
  }

  @override
  ContentProcessor? createCommandProcessor(String msgType, String cmd) {
    switch (cmd) {
      case Command.RECEIPT:
        return ReceiptCommandProcessor(facebook!, messenger!);
      case HandshakeCommand.HANDSHAKE:
        return HandshakeCommandProcessor(facebook!, messenger!);
      case LoginCommand.LOGIN:
        return LoginCommandProcessor(facebook!, messenger!);
      case AnsCommand.ANS:
        return AnsCommandProcessor(facebook!, messenger!);

      // group commands
      case 'group':
        return GroupCommandProcessor(facebook!, messenger!);
      case GroupCommand.INVITE:
        return InviteCommandProcessor(facebook!, messenger!);
      case GroupCommand.EXPEL:
        /// Deprecated (use 'reset' instead)
        return ExpelCommandProcessor(facebook!, messenger!);
      case GroupCommand.JOIN:
        return JoinCommandProcessor(facebook!, messenger!);
      case GroupCommand.QUIT:
        return QuitCommandProcessor(facebook!, messenger!);
      case QueryCommand.QUERY:
        return QueryCommandProcessor(facebook!, messenger!);
      case GroupCommand.RESET:
        return ResetCommandProcessor(facebook!, messenger!);
      case GroupCommand.RESIGN:
        return ResignCommandProcessor(facebook!, messenger!);

      // efficient commands
      case Command.META:
        return EfficientMetaCommandProcessor(facebook!, messenger!);
      case Command.DOCUMENTS:
        return EfficientDocumentCommandProcessor(facebook!, messenger!);
    }
    // others
    return super.createCommandProcessor(msgType, cmd);
  }

}
