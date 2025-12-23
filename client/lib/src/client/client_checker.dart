/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import 'package:object_key/object_key.dart';

import '../common/protocol/groups.dart';
import '../common/checker.dart';
import '../common/facebook.dart';
import '../common/messenger.dart';
import '../common/session.dart';

class ClientChecker extends EntityChecker {
  ClientChecker(CommonFacebook facebook, super.database)
      : _barrack = WeakReference(facebook);

  final WeakReference<CommonFacebook> _barrack;
  WeakReference<CommonMessenger>? _transceiver;

  // protected
  CommonFacebook? get facebook => _barrack.target;

  // protected
  CommonMessenger? get messenger => _transceiver?.target;
  // public
  set messenger(CommonMessenger? delegate) =>
      _transceiver = delegate == null ? null : WeakReference(delegate);

  @override
  Future<bool> queryMeta(ID identifier, {required List<ID> respondents}) async {
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    Transmitter? transmitter = messenger;
    if (transmitter == null) {
      logWarning('messenger not ready yet, cannot query meta now: $identifier');
      return false;
    }
    Content content = MetaCommand.query(identifier);
    logInfo('querying meta for: $identifier << $respondents');
    int success = 0;
    Pair<InstantMessage, ReliableMessage?> pair;
    for (ID receiver in respondents) {
      if (receiver == me) {
        logWarning('ignore cycled querying: $identifier, receiver: $receiver');
        continue;
      } else if (!isMetaQueryExpired(identifier, respondent: receiver)) {
        logInfo('meta query not expired yet: $identifier');
        continue;
      }
      pair = await transmitter.sendContent(content, sender: me, receiver: receiver, priority: 1);
      if (pair.second != null) {
        success += 1;
      }
    }
    return success > 0;
  }

  @override
  Future<bool> queryDocuments(ID identifier, DateTime? lastTime, {required List<ID> respondents}) async {
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    Transmitter? transmitter = messenger;
    if (transmitter == null) {
      logWarning('messenger not ready yet, cannot query documents now: $identifier');
      return false;
    }
    Content content = DocumentCommand.query(identifier, lastTime);
    logInfo('querying documents for: $identifier, last time: $lastTime << $respondents');
    int success = 0;
    Pair<InstantMessage, ReliableMessage?> pair;
    for (ID receiver in respondents) {
      if (receiver == me) {
        logWarning('ignore cycled querying: $identifier, receiver: $receiver');
        continue;
      } else if (!isDocumentQueryExpired(identifier, respondent: receiver)) {
        logInfo('document query not expired yet: $identifier');
        continue;
      }
      pair = await transmitter.sendContent(content, sender: me, receiver: receiver, priority: 1);
      if (pair.second != null) {
        success += 1;
      }
    }
    return success > 0;
  }

  @override
  Future<bool> queryMembers(ID group, DateTime? lastTime, {required List<ID> respondents}) async {
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    Transmitter? transmitter = messenger;
    if (transmitter == null) {
      logWarning('messenger not ready yet, cannot query members now: $group');
      return false;
    }
    // add owner, administrators to respondents
    ID? owner = await facebook?.getOwner(group);
    if (owner == null) {
      logWarning('owner not found for group: $group');
    } else {
      respondents.add(owner);
    }
    List<ID>? admins = await facebook?.getAdministrators(group);
    if (admins == null || admins.isEmpty) {
      logWarning('administrators not found for group: $group');
    } else {
      respondents.addAll(admins);
    }
    // TODO: use 'GroupHistory.queryGroupHistory(group, lastTime)' instead
    Content content = QueryCommand.query(group, lastTime);
    logInfo('querying members for group: $group, last time: $lastTime << $respondents');
    int success = 0;
    Pair<InstantMessage, ReliableMessage?> pair;
    for (ID receiver in respondents) {
      if (receiver == me) {
        logWarning('ignore cycled querying: $group, receiver: $receiver');
        continue;
      } else if (!isMembersQueryExpired(group, respondent: receiver)) {
        logInfo('members query not expired yet: $group');
        continue;
      }
      pair = await transmitter.sendContent(content, sender: me, receiver: receiver, priority: 1);
      if (pair.second != null) {
        success += 1;
      }
    }
    return success > 0;
  }

  ///  Send my visa document to contact
  ///  if document is updated, force to send it again.
  ///  else only send once every 10 minutes.
  @override
  Future<bool> sendVisa(Visa visa, ID contact, {bool updated = false}) async {
    ID me = visa.identifier;
    if (me == contact) {
      logWarning('skip cycled message: $contact, $visa');
      return false;
    }
    Transmitter? transmitter = messenger;
    if (transmitter == null) {
      logWarning('messenger not ready yet');
      return false;
    }
    if (!isDocumentResponseExpired(contact, updated)) {
      // response not expired yet
      logDebug('visa response not expired yet: $contact');
      return false;
    }
    logDebug('push visa document: $me => $contact');
    DocumentCommand command = DocumentCommand.response(me, null, [visa]);
    var res = await transmitter.sendContent(command, sender: me, receiver: contact, priority: 1);
    return res.second != null;
  }

}
