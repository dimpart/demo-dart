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

import 'checker.dart';
import 'facebook.dart';

abstract class CommonProcessor extends MessageProcessor with Logging {
  CommonProcessor(super.facebook, super.messenger);

  EntityChecker? get entityChecker {
    var facebook = this.facebook;
    if (facebook is CommonFacebook) {
      return facebook.entityChecker;
    }
    assert(facebook == null, 'facebook error: $facebook');
    return null;
  }

  @override
  ContentProcessorFactory createFactory(Facebook facebook, Messenger messenger) {
    var creator = createCreator(facebook, messenger);
    return GeneralContentProcessorFactory(creator);
  }
  // protected
  ContentProcessorCreator createCreator(Facebook facebook, Messenger messenger);

  // private
  Future<bool> checkVisaTime(Content content, ReliableMessage rMsg) async {
    var checker = entityChecker;
    if (checker == null) {
      assert(false, 'should not happen');
      return false;
    }
    bool docUpdated = false;
    // check sender document time
    DateTime? lastDocumentTime = rMsg.getDateTime('SDT');
    if (lastDocumentTime != null) {
      DateTime now = DateTime.now();
      if (lastDocumentTime.isAfter(now)) {
        // calibrate the clock
        lastDocumentTime = now;
      }
      ID sender = rMsg.sender;
      docUpdated = checker.setLastDocumentTime(lastDocumentTime, sender);
      // check whether needs update
      if (docUpdated) {
        logInfo('checking for new visa: $sender');
        await checker.checkDocuments(sender, null, sender: rMsg.sender);
      }
    }
    return docUpdated;
  }

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    List<Content> responses = await super.processContent(content, rMsg);

    // check sender's document times from the message
    // to make sure the user info synchronized
    await checkVisaTime(content, rMsg);

    return responses;
  }

}
