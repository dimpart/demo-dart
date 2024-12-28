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

import '../common/messenger.dart';

import 'delegate.dart';
import 'packer.dart';


class GroupEmitter extends TripletsHelper {
  GroupEmitter(super.delegate);

  // NOTICE: group assistants (bots) can help the members to redirect messages
  //
  //      if members.length < POLYLOGUE_LIMIT,
  //          means it is a small polylogue group, let the members to split
  //          and send group messages by themselves, this can keep the group
  //          more secretive because no one else can know the group ID even;
  //      else,
  //          set 'assistants' in the bulletin document to tell all members
  //          that they can let the group bot to do the job for them.
  //
  // ignore: non_constant_identifier_names
  static int POLYLOGUE_LIMIT = 32;

  // NOTICE: expose group ID to reduce encrypting time
  //
  //      if members.length < SECRET_GROUP_LIMIT,
  //          means it is a tiny group, you can choose to hide the group ID,
  //          that you can split and encrypt message one by one;
  //      else,
  //          you should expose group ID in the instant message level, then
  //          encrypt message by one symmetric key for this group, after that,
  //          split and send to all members directly.
  //
  // ignore: non_constant_identifier_names
  static int SECRET_GROUP_LIMIT = 16;

  // protected
  late final GroupPacker packer = createPacker();

  /// override for customized packer
  GroupPacker createPacker() => GroupPacker(delegate);

  // private
  Future<bool> attachGroupTimes(ID group, InstantMessage iMsg) async {
    if (iMsg.content is GroupCommand) {
      // no need to attach times for group command
      return false;
    }
    Bulletin? doc = await facebook?.getBulletin(group);
    if (doc == null) {
      assert(false, 'failed to get bulletin document for group: $group');
      return false;
    }
    // attach group document time
    DateTime? lastDocumentTime = doc.time;
    if (lastDocumentTime == null) {
      assert(false, 'document error: $doc');
    } else {
      iMsg.setDateTime('GDT', lastDocumentTime);
    }
    // attach group history time
    var checker = facebook?.checker;
    DateTime? lastHistoryTime = await checker?.getLastGroupHistoryTime(group);
    if (lastHistoryTime == null) {
      assert(false, 'failed to get history time: $group');
    } else {
      iMsg.setDateTime('GHT', lastHistoryTime);
    }
    return true;
  }

  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    //
    //  0. check group
    //
    Content content = iMsg.content;
    ID? group = content.group;
    if (group == null) {
      assert(false, 'not a group message: $iMsg');
      return null;
    } else {
      logDebug('send instant message (type=${iMsg.content.type}): '
          '${iMsg.sender} => ${iMsg.receiver}, ${iMsg.group}');
      // attach group's document & history times
      // for the receiver to check whether group info synchronized
      bool ok = await attachGroupTimes(group, iMsg);
      assert(ok || content is GroupCommand, 'failed to attach group times: $group => $content');
    }
    assert(iMsg.receiver == group, 'group message error: $iMsg');

    /// NOTICE: even if the message content is a FileContent,
    ///         there is no need to process the file data here too, because
    ///         the message packer will handle it before encryption.

    //
    //  1. check group bots
    //
    ID? prime = await delegate.getFastestAssistant(group);
    if (prime != null) {
      // group bots found, forward this message to any bot to let it split for me;
      // this can reduce my jobs.
      return await _forwardMessage(iMsg, prime, group: group, priority: priority);
    }

    //
    //  2. check group members
    //
    List<ID> members = await delegate.getMembers(group);
    if (members.isEmpty) {
      assert(false, 'failed to get members for group: $group');
      return null;
    }
    // no 'assistants' found in group's bulletin document?
    // split group messages and send to all members one by one
    if (members.length < SECRET_GROUP_LIMIT) {
      // it is a tiny group, split this message before encrypting and signing,
      // then send this group message to all members one by one
      int success = await _splitAndSendMessage(iMsg, members, group: group, priority: priority);
      logInfo('split $success message(s) for group: $group');
      return null;
    } else {
      logInfo('splitting message for ${members.length} members of group: $group');
      // encrypt and sign this message first,
      // then split and send to all members one by one
      return await _disperseMessage(iMsg, members, group: group, priority: priority);
    }
  }

  /// Encrypt & sign message, then forward to the bot
  Future<ReliableMessage?> _forwardMessage(InstantMessage iMsg, ID bot, {required ID group, int priority = 0}) async {
    assert(bot.isUser && group.isGroup, 'ID error: $bot, $group');
    // NOTICE: because group assistant (bot) cannot be a member of the group, so
    //         if you want to send a group command to any assistant, you must
    //         set the bot ID as 'receiver' and set the group ID in content;
    //         this means you must send it to the bot directly.
    CommonMessenger? transceiver = messenger;

    // group bots designated, let group bot to split the message, so
    // here must expose the group ID; this will cause the client to
    // use a "user-to-group" encrypt key to encrypt the message content,
    // this key will be encrypted by each member's public key, so
    // all members will received a message split by the group bot,
    // but the group bots cannot decrypt it.
    iMsg.setString('group', group);

    // the group bot can only get the message 'signature',
    // but cannot know the 'sn' because it cannot decrypt the content,
    // this is usually not a problem;
    // but sometimes we want to respond a receipt with original sn,
    // so I suggest to expose 'sn' too.
    int sn = iMsg.content.sn;
    iMsg['sn'] = sn;

    //
    //  1. pack message
    //
    ReliableMessage? rMsg = await packer.encryptAndSignMessage(iMsg);
    if (rMsg == null) {
      assert(false, 'failed to encrypt & sign message: ${iMsg.sender} => $group');
      return null;
    }

    //
    //  2. forward the group message to any bot
    //
    Content content = ForwardContent.create(forward: rMsg);
    var pair = await transceiver?.sendContent(content, sender: null, receiver: bot, priority: priority);
    if (pair == null || pair.second == null) {
      assert(false, 'failed to forward message for group: $group, bot: $bot');
    }

    // OK, return the forwarding message
    return rMsg;
  }

  /// Encrypt & sign message, then disperse to all members
  Future<ReliableMessage?> _disperseMessage(InstantMessage iMsg, List<ID> members, {required ID group, int priority = 0}) async {
    assert(group.isGroup, 'group ID error: $group');
    // assert(!iMsg.containsKey('group'), 'should not happen');
    CommonMessenger? transceiver = messenger;

    // NOTICE: there are too many members in this group
    //         if we still hide the group ID, the cost will be very high.
    //  so,
    //      here I suggest to expose 'group' on this message's envelope
    //      to use a user-to-group password to encrypt the message content,
    //      and the actual receiver can get the decrypt key
    //      with the accurate direction: (sender -> group)
    iMsg.setString('group', group);

    ID sender = iMsg.sender;

    //
    //  0. pack message
    //
    ReliableMessage? rMsg = await packer.encryptAndSignMessage(iMsg);
    if (rMsg == null) {
      assert(false, 'failed to encrypt & sign message: $sender => $group');
      return null;
    }

    //
    //  1. split messages
    //
    List<ReliableMessage> messages = await packer.splitReliableMessage(rMsg, members);
    ID receiver;
    bool? ok;
    for (ReliableMessage msg in messages) {
      receiver = msg.receiver;
      if (sender == receiver) {
        assert(false, 'cycled message: $sender => $receiver, $group');
        continue;
      }
      //
      //  2. send message
      //
      ok = await transceiver?.sendReliableMessage(msg, priority: priority);
      assert(ok == true, 'failed to send message: $sender => $receiver, $group');
    }

    return rMsg;
  }

  /// Split and send (encrypt + sign) group messages to all members one by one
  Future<int> _splitAndSendMessage(InstantMessage iMsg, List<ID> members, {required ID group, int priority = 0}) async {
    assert(group.isGroup, 'group ID error: $group');
    assert(!iMsg.containsKey('group'), 'should not happen');
    CommonMessenger? transceiver = messenger;

    // NOTICE: this is a tiny group
    //         I suggest NOT to expose the group ID to maximize its privacy,
    //         the cost is we cannot use a user-to-group password here;
    //         So the other members can only treat it as a personal message
    //         and use the user-to-user symmetric key to decrypt content,
    //         they can get the group ID after decrypted.

    ID sender = iMsg.sender;
    int success = 0;

    //
    //  1. split messages
    //
    List<InstantMessage> messages = await packer.splitInstantMessage(iMsg, members);
    ID receiver;
    ReliableMessage? rMsg;
    for (InstantMessage msg in messages) {
      receiver = msg.receiver;
      if (sender == receiver) {
        assert(false, 'cycled message: $sender => $receiver, $group');
        continue;
      }
      //
      //  2. send message
      //
      rMsg = await transceiver?.sendInstantMessage(msg, priority: priority);
      if (rMsg == null) {
        logError('failed to send message: $sender => $receiver, $group');
        continue;
      }
      success += 1;
    }

    // done!
    return success;
  }

}
