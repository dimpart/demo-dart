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

import '../../dim_common.dart';
import '../facebook.dart';
import '../messenger.dart';
import '../network/session.dart';


class AnsCommandProcessor extends BaseCommandProcessor {
  AnsCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is AnsCommand, 'ans command error: $content');
    AnsCommand command = content as AnsCommand;
    Map<String, String> records = command.records;
    int count = await ClientFacebook.ans!.fix(records);
    Log.info('ANS: update $count record(s), $records');
    return [];
  }

}


class LoginCommandProcessor extends BaseCommandProcessor {
  LoginCommandProcessor(super.facebook, super.messenger);

  @override
  ClientMessenger get messenger => super.messenger as ClientMessenger;

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is LoginCommand, 'login command error: $content');
    LoginCommand command = content as LoginCommand;
    ID sender = command.identifier;
    assert(rMsg.sender == sender, 'sender not match: $sender, ${rMsg.sender}');
    // save login command to session db
    ClientSession session = messenger.session;
    SessionDBI db = session.database;
    if (await db.saveLoginCommandMessage(sender, command, rMsg)) {
      Log.info('saved login command for user: $sender');
    } else {
      Log.error('failed to save login command: $sender, $command');
    }
    // no need to response login command
    return [];
  }

}


class ReceiptCommandProcessor extends BaseCommandProcessor {
  ReceiptCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is ReceiptCommand, 'receipt command error: $content');
    // no need to response login command
    return [];
  }

}
