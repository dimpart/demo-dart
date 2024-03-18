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

import '../common/processor.dart';
import '../common/protocol/handshake.dart';

import 'cpu/creator.dart';

import 'archivist.dart';
import 'messenger.dart';

class ClientMessageProcessor extends CommonProcessor {
  ClientMessageProcessor(super.facebook, super.messenger);

  @override
  ClientMessenger? get messenger => super.messenger as ClientMessenger?;

  // private
  Future<bool> checkGroupTimes(Content content, ReliableMessage rMsg) async {
    ID? group = content.group;
    if (group == null) {
      return false;
    }
    ClientArchivist? archivist = facebook?.archivist as ClientArchivist?;
    if (archivist == null) {
      assert(false, 'should not happen');
      return false;
    }
    DateTime now = DateTime.now();
    bool docUpdated = false;
    bool memUpdated = false;
    // check group document time
    DateTime? lastDocumentTime = rMsg.getDateTime('GDT', null);
    if (lastDocumentTime != null) {
      if (lastDocumentTime.isAfter(now)) {
        // calibrate the clock
        lastDocumentTime = now;
      }
      docUpdated = archivist.setLastDocumentTime(group, lastDocumentTime);
      // check whether needs update
      if (docUpdated) {
        logInfo('checking for new bulletin: $group');
        await facebook?.getDocuments(group);
      }
    }
    // check group history time
    DateTime? lastHistoryTime = rMsg.getDateTime('GHT', null);
    if (lastHistoryTime != null) {
      if (lastHistoryTime.isAfter(now)) {
        // calibrate the clock
        lastHistoryTime = now;
      }
      memUpdated = archivist.setLastGroupHistoryTime(group, lastHistoryTime);
      if (memUpdated) {
        archivist.setLastActiveMember(group: group, member: rMsg.sender);
        logInfo('checking for group members: $group');
        await facebook?.getMembers(group);
      }
    }
    return docUpdated || memUpdated;
  }

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    List<Content> responses = await super.processContent(content, rMsg);

    // check group's document & history times from the message
    // to make sure the group info synchronized
    await checkGroupTimes(content, rMsg);

    if (responses.isEmpty) {
      // respond nothing
      return responses;
    } else if (responses.first is HandshakeCommand) {
      // urgent command
      return responses;
    }
    ID sender = rMsg.sender;
    ID receiver = rMsg.receiver;
    User? user = await facebook?.selectLocalUser(receiver);
    if (user == null) {
      assert(false, "receiver error: $receiver");
      return responses;
    }
    receiver = user.identifier;
    // check responses
    for (Content res in responses) {
      if (res is ReceiptCommand) {
        if (sender.type == EntityType.kStation) {
          // no need to respond receipt to station
          continue;
        } else if (sender.type == EntityType.kBot) {
          // no need to respond receipt to a bot
          continue;
        }
      } else if (res is TextContent) {
        if (sender.type == EntityType.kStation) {
          // no need to respond text message to station
          continue;
        } else if (sender.type == EntityType.kBot) {
          // no need to respond text message to a bot
          continue;
        }
      }
      // normal response
      await messenger?.sendContent(res, sender: receiver, receiver: sender, priority: 1);
    }
    // DON'T respond to station directly
    return [];
  }

  @override
  ContentProcessorCreator createCreator() {
    return ClientContentProcessorCreator(facebook!, messenger!);
  }

}
