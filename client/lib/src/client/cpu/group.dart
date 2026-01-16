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
import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';

import '../../common/facebook.dart';
import '../../common/messenger.dart';
import '../../group/delegate.dart';
import '../../group/helper.dart';
import '../../group/builder.dart';

class HistoryCommandProcessor extends BaseCommandProcessor with Logging {
  HistoryCommandProcessor(super.facebook, super.messenger);

  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is HistoryCommand, 'history command error: $content');
    HistoryCommand command = content as HistoryCommand;
    String text = 'Command not support.';
    return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'History command (name: \${cmd}) not support yet!',
      'replacements': {
        'cmd': command.cmd,
      },
    });
  }

}


class GroupCommandProcessor extends HistoryCommandProcessor {
  GroupCommandProcessor(super.facebook, super.messenger);

  // protected
  late final GroupDelegate delegate = createdDelegate();
  // protected
  late final GroupCommandHelper helper = createdHelper();
  // protected
  late final GroupHistoryBuilder builder = createBuilder();

  /// override for customized data source
  GroupDelegate createdDelegate() => GroupDelegate(facebook!, messenger!);

  /// override for customized helper
  GroupCommandHelper createdHelper() => GroupCommandHelper(delegate);

  /// override for customized builder
  GroupHistoryBuilder createBuilder() => GroupHistoryBuilder(delegate);

  // protected
  Future<ID?> getOwner(ID group) async =>
      await delegate.getOwner(group);

  // protected
  Future<List<ID>> getAdministrators(ID group) async =>
      await delegate.getAdministrators(group);
  // protected
  Future<bool> saveAdministrators(ID group, List<ID> admins) async =>
      await delegate.saveAdministrators(admins, group);

  // protected
  Future<List<ID>> getMembers(ID group) async =>
      await delegate.getMembers(group);
  // protected
  Future<bool> saveMembers(ID group, List<ID> members) async =>
      await delegate.saveMembers(members, group);

  // protected
  Future<bool> saveGroupHistory(ID group, GroupCommand content, ReliableMessage rMsg) async =>
      await helper.saveGroupHistory(group, content, rMsg);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is GroupCommand, 'group command error: $content');
    GroupCommand command = content as GroupCommand;
    String text = 'Command not support.';
    return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'Group command (name: \${cmd}) not support yet!',
      'replacements': {
        'cmd': command.cmd,
      },
    });
  }

  // protected
  Future<Pair<ID?, List<Content>?>> checkCommandExpired(GroupCommand content, ReliableMessage rMsg) async {
    ID? group = content.group;
    if (group == null) {
      assert(false, 'group command error: $content');
      return Pair(null, null);
    }
    List<Content>? errors;
    bool expired = await helper.isCommandExpired(content);
    if (expired) {
      String text = 'Command expired.';
      errors = respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Group command expired: \${cmd}, group: \${gid}',
        'replacements': {
          'cmd': content.cmd,
          'gid': group.toString(),
        }
      });
      group = null;
    } else {
      // group ID must not empty here
      errors = null;
    }
    return Pair(group, errors);
  }

  // protected
  Future<Pair<List<ID>, List<Content>?>> checkCommandMembers(GroupCommand content, ReliableMessage rMsg) async {
    ID? group = content.group;
    if (group == null) {
      assert(false, 'group command error: $content');
      return Pair([], null);
    }
    List<Content>? errors;
    List<ID> members = await helper.getMembersFromCommand(content);
    if (members.isEmpty) {
      String text = 'Command error.';
      errors = respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Group members empty: \${gid}',
        'replacements': {
          'gid': group.toString(),
        }
      });
    } else {
      // normally
      errors = null;
    }
    return Pair(members, errors);
  }

  // protected
  Future<Triplet<ID?, List<ID>, List<Content>?>> checkGroupMembers(GroupCommand content, ReliableMessage rMsg) async {
    ID? group = content.group;
    if (group == null) {
      assert(false, 'group command error: $content');
      return Triplet(null, [], null);
    }
    List<Content>? errors;
    ID? owner = await getOwner(group);
    List<ID> members = await getMembers(group);
    if (owner == null || members.isEmpty) {
      // TODO: query group members?
      String text = 'Group empty.';
      errors = respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Group empty: \${gid}',
        'replacements': {
          'gid': group.toString(),
        }
      });
    } else {
      // group is ready
      errors = null;
    }
    return Triplet(owner, members, errors);
  }

  /// send a command list with newest members to the receiver
  Future<bool> sendGroupHistories({required ID group, required ID receiver}) async {
    List<ReliableMessage> messages = await builder.buildGroupHistories(group);
    if (messages.isEmpty) {
      logWarning('failed to build history for group: $group');
      return false;
    }
    var checker = facebook?.entityChecker;
    if (checker == null) {
      assert(false, 'failed to get entity checker');
      return false;
    }
    return await checker.sendHistories(group, messages, recipients: [receiver]);
  }

}
