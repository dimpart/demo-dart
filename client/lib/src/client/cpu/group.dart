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


class HistoryCommandProcessor extends BaseCommandProcessor {
  HistoryCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is HistoryCommand, 'history command error: $content');
    HistoryCommand command = content as HistoryCommand;
    String text = 'Command not support.';
    return respondReceipt(text, rMsg, group: content.group, extra: {
      'template': 'History command (name: \${command}) not support yet!',
      'replacements': {
        'command': command.cmd,
      },
    });
  }

}


class GroupCommandProcessor extends HistoryCommandProcessor {
  GroupCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is GroupCommand, 'group command error: $content');
    GroupCommand command = content as GroupCommand;
    String text = 'Command not support.';
    return respondReceipt(text, rMsg, group: content.group, extra: {
      'template': 'Group command (name: \${command}) not support yet!',
      'replacements': {
        'command': command.cmd,
      },
    });
  }

  // protected
  List<ID> getMembers(GroupCommand content) {
    // get from 'members'
    List<ID>? members = content.members;
    if (members == null) {
      members = [];
      // get from 'member'
      ID? member = content.member;
      if (member != null) {
        members.add(member);
      }
    }
    return members;
  }

}
