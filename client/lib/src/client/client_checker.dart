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
import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';

import '../common/checker.dart';
import '../common/facebook.dart';
import '../common/messenger.dart';

class ClientChecker extends EntityChecker with Logging {
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
  Future<bool> queryMeta(ID identifier) async {
    if (!isMetaQueryExpired(identifier)) {
      // query not expired yet
      logInfo('meta query not expired yet: $identifier');
      return false;
    }
    logInfo('querying meta for: $identifier');
    var content = MetaCommand.query(identifier);
    var pair = await messenger?.sendContent(content,
      sender: null, receiver: Station.ANY, priority: 1,);
    return pair?.second != null;
  }

  @override
  Future<bool> queryDocuments(ID identifier, List<Document> documents) async {
    if (!isDocumentQueryExpired(identifier)) {
      // query not expired yet
      logInfo('document query not expired yet: $identifier');
      return false;
    }
    DateTime? lastTime = getLastDocumentTime(identifier, documents);
    logInfo('querying documents for: $identifier, last time: $lastTime');
    var content = DocumentCommand.query(identifier, lastTime);
    var pair = await messenger?.sendContent(content,
        sender: null, receiver: Station.ANY, priority: 1);
    return pair?.second != null;
  }

  @override
  Future<bool> queryMembers(ID group, List<ID> members) async {
    if (!isMembersQueryExpired(group)) {
      // query not expired yet
      logInfo('members query not expired yet: $group');
      return false;
    }
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    DateTime? lastTime = await getLastGroupHistoryTime(group);
    logInfo('querying members for group: $group, last time: $lastTime');
    // build query command for group members
    var command = GroupCommand.query(group, lastTime);
    bool ok;
    // 1. check group bots
    ok = await queryMembersFromAssistants(command, sender: me, group: group);
    if (ok) {
      return true;
    }
    // 2. check administrators
    ok = await queryMembersFromAdministrators(command, sender: me, group: group);
    if (ok) {
      return true;
    }
    // 3. check group owner
    ok = await queryMembersFromOwner(command, sender: me, group: group);
    if (ok) {
      return true;
    }
    Pair<InstantMessage, ReliableMessage?>? pair;
    // all failed, try last active member
    ID? lastMember = getLastActiveMember(group: group);
    if (lastMember != null) {
      logInfo('querying members from: $lastMember, group: $group');
      pair = await messenger?.sendContent(command, sender: me, receiver: lastMember, priority: 1);
    }
    logError('group not ready: $group');
    return pair?.second != null;
  }

  // protected
  Future<bool> queryMembersFromAssistants(QueryCommand command, {required ID sender, required ID group}) async {
    List<ID>? bots = await facebook?.getAssistants(group);
    if (bots == null || bots.isEmpty) {
      logWarning('assistants not designated for group: $group');
      return false;
    }
    int success = 0;
    Pair<InstantMessage, ReliableMessage?>? pair;
    // querying members from bots
    logInfo('querying members from bots: $bots, group: $group');
    for (ID receiver in bots) {
      if (sender == receiver) {
        logWarning('ignore cycled querying: $sender, group: $group');
        continue;
      }
      pair = await messenger?.sendContent(command, sender: sender, receiver: receiver, priority: 1);
      if (pair?.second != null) {
        success += 1;
      }
    }
    if (success == 0) {
      // failed
      return false;
    }
    ID? lastMember = getLastActiveMember(group: group);
    if (lastMember == null || bots.contains(lastMember)) {
      // last active member is a bot??
    } else {
      logInfo('querying members from: $lastMember, group: $group');
      await messenger?.sendContent(command, sender: sender, receiver: lastMember, priority: 1);
    }
    return true;
  }

  // protected
  Future<bool> queryMembersFromAdministrators(QueryCommand command, {required ID sender, required ID group}) async {
    List<ID>? admins = await facebook?.getAdministrators(group);
    if (admins == null || admins.isEmpty) {
      logWarning('administrators not found for group: $group');
      return false;
    }
    int success = 0;
    Pair<InstantMessage, ReliableMessage?>? pair;
    // querying members from admins
    logInfo('querying members from admins: $admins, group: $group');
    for (ID receiver in admins) {
      if (sender == receiver) {
        logWarning('ignore cycled querying: $sender, group: $group');
        continue;
      }
      pair = await messenger?.sendContent(command, sender: sender, receiver: receiver, priority: 1);
      if (pair?.second != null) {
        success += 1;
      }
    }
    if (success == 0) {
      // failed
      return false;
    }
    ID? lastMember = getLastActiveMember(group: group);
    if (lastMember == null || admins.contains(lastMember)) {
      // last active member is an admin, already queried
    } else {
      logInfo('querying members from: $lastMember, group: $group');
      await messenger?.sendContent(command, sender: sender, receiver: lastMember, priority: 1);
    }
    return true;
  }

  // protected
  Future<bool> queryMembersFromOwner(QueryCommand command, {required ID sender, required ID group}) async {
    ID? owner = await facebook?.getOwner(group);
    if (owner == null) {
      logWarning('owner not found for group: $group');
      return false;
    } else if (owner == sender) {
      logError('you are the owner of group: $group');
      return false;
    }
    Pair<InstantMessage, ReliableMessage?>? pair;
    // querying members from owner
    logInfo('querying members from owner: $owner, group: $group');
    pair = await messenger?.sendContent(command, sender: sender, receiver: owner, priority: 1);
    if (pair?.second == null) {
      // failed
      return false;
    }
    ID? lastMember = getLastActiveMember(group: group);
    if (lastMember == null || lastMember == owner) {
      // last active member is the owner, already queried
    } else {
      logInfo('querying members from: $lastMember, group: $group');
      messenger?.sendContent(command, sender: sender, receiver: lastMember, priority: 1);
    }
    return true;
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
    if (!isDocumentResponseExpired(contact, updated)) {
      // response not expired yet
      logDebug('visa response not expired yet: $contact');
      return false;
    }
    logInfo('push visa document: $me => $contact');
    DocumentCommand command = DocumentCommand.response(me, null, visa);
    var res = await messenger?.sendContent(command, sender: me, receiver: contact, priority: 1);
    return res?.second != null;
  }

}
