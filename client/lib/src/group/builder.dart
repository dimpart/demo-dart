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
import 'package:object_key/object_key.dart';

import 'delegate.dart';
import 'helper.dart';


class GroupHistoryBuilder extends TripletsHelper {
  GroupHistoryBuilder(super.delegate);

  // protected
  late final GroupCommandHelper helper = createHelper();

  /// override for customized helper
  GroupCommandHelper createHelper() => GroupCommandHelper(delegate);

  /// build command list for group history:
  ///     0. document command
  ///     1. reset group command
  ///     2. other group commands
  Future<List<ReliableMessage>> buildGroupHistories(ID group) async {
    List<ReliableMessage> messages = [];
    Document? doc;
    ResetCommand? reset;
    ReliableMessage? rMsg;
    //
    //  0. build 'document' command
    //
    Pair<Document?, ReliableMessage?> docPair = await buildDocumentCommand(group);
    doc = docPair.first;
    rMsg = docPair.second;
    if (doc == null || rMsg == null) {
      logWarning('failed to build "document" command for group: $group');
      return messages;
    } else {
      messages.add(rMsg);
    }
    //
    //  1. append 'reset' command
    //
    Pair<ResetCommand?, ReliableMessage?> resPair = await helper.getResetCommandMessage(group);
    reset = resPair.first;
    rMsg = resPair.second;
    if (reset == null || rMsg == null) {
      logWarning('failed to get "reset" command for group: $group');
      return messages;
    } else {
      messages.add(rMsg);
    }
    //
    //  2. append other group commands
    //
    List<Pair<GroupCommand, ReliableMessage>> history = await helper.getGroupHistories(group);
    for (var item in history) {
      if (item.first is ResetCommand) {
        // 'reset' command already add to the front
        // assert(messages.length == 2, 'group history error: $group, ${history.length}');
        logInfo('skip "reset" command for group: $group');
        continue;
      } else if (item.first is ResignCommand) {
        // 'resign' command, comparing it with document time
        if (DocumentHelper.isBefore(doc.time, item.first.time)) {
          logWarning('expired "${item.first.cmd}" command in group: $group, sender: ${item.second.sender}');
          continue;
        }
      } else {
        // other commands('invite', 'join', 'quit'), comparing with 'reset' time
        if (DocumentHelper.isBefore(reset.time, item.first.time)) {
          logWarning('expired "${item.first.cmd}" command in group: $group, sender: ${item.second.sender}');
          continue;
        }
      }
      messages.add(item.second);
    }
    // OK
    return messages;
  }

  /// create broadcast 'document' command
  Future<Pair<Document?, ReliableMessage?>> buildDocumentCommand(ID group) async {
    User? user = await facebook?.currentUser;
    Bulletin? doc = await delegate.getBulletin(group);
    if (user == null || doc == null) {
      assert(user != null, 'failed to get current user');
      logError('document not found for group: $group');
      return Pair(null, null);
    }
    ID me = user.identifier;
    Meta? meta = await delegate.getMeta(group);
    Command command = DocumentCommand.response(group, meta, doc);
    ReliableMessage? rMsg = await _packBroadcastMessage(me, command);
    return Pair(doc, rMsg);
  }

  /// create broadcast 'reset' group command with newest member list
  Future<Pair<ResetCommand?, ReliableMessage?>> buildResetCommand(ID group, [List<ID>? members]) async {
    User? user = await facebook?.currentUser;
    ID? owner = await delegate.getOwner(group);
    if (user == null || owner == null) {
      assert(user != null, 'failed to get current user');
      logError('owner not found for group: $group');
      return Pair(null, null);
    }
    ID me = user.identifier;
    if (owner != me) {
      List<ID> admins = await delegate.getAdministrators(group);
      if (!admins.contains(me)) {
        logWarning('not permit to build "reset" command for group: $group, $me');
        return Pair(null, null);
      }
    }
    members ??= await delegate.getMembers(group);
    assert(members.isNotEmpty, 'group members not found: $group');
    ResetCommand command = GroupCommand.reset(group, members: members);
    ReliableMessage? rMsg = await _packBroadcastMessage(me, command);
    return Pair(command, rMsg);
  }

  Future<ReliableMessage?> _packBroadcastMessage(ID sender, Content content) async {
    Envelope envelope = Envelope.create(sender: sender, receiver: ID.kAnyone);
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    SecureMessage? sMsg = await messenger?.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message: $envelope');
      return null;
    }
    ReliableMessage? rMsg = await messenger?.signMessage(sMsg);
    assert(rMsg != null, 'failed to sign message: $envelope');
    return rMsg;
  }

}
