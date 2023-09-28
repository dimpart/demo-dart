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
import '../dim_common.dart';
import 'cpu/creator.dart';

class ClientMessageProcessor extends MessageProcessor {
  ClientMessageProcessor(super.facebook, super.messenger);

  @override
  CommonMessenger get messenger => super.messenger as CommonMessenger;

  @override
  CommonFacebook get facebook => super.facebook as CommonFacebook;

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    List<Content> responses = await super.processContent(content, rMsg);
    if (responses.isEmpty) {
      // respond nothing
      return responses;
    } else if (responses.first is HandshakeCommand) {
      // urgent command
      return responses;
    }
    ID sender = rMsg.sender;
    ID receiver = rMsg.receiver;
    User? user = await facebook.selectLocalUser(receiver);
    if (user == null) {
      assert(false, "receiver error: $receiver");
      return [];
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
      await messenger.sendContent(res, sender: receiver, receiver: sender, priority: 1);
    }
    // DON'T respond to station directly
    return [];
  }

  @override
  ContentProcessorCreator createCreator() {
    return ClientContentProcessorCreator(facebook, messenger);
  }

}
