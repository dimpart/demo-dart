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
import 'package:lnc/lnc.dart';
import 'package:object_key/object_key.dart';

import '../common/archivist.dart';
import '../common/facebook.dart';
import '../common/messenger.dart';
import 'facebook.dart';

abstract class ClientArchivist extends CommonArchivist {

  // each respond will be expired after 10 minutes
  static const double kRespondExpires = 600.0;  // seconds

  final FrequencyChecker<ID> _documentResponses;

  // group => member
  final Map<ID, ID> _lastActiveMembers = {};

  ClientArchivist(super.database)
      : _documentResponses = FrequencyChecker(kRespondExpires);

  // protected
  bool isDocumentResponseExpired(ID identifier, bool force) =>
      _documentResponses.isExpired(identifier, force: force);

  void setLastActiveMember({required ID group, required ID member}) =>
      _lastActiveMembers[group] = member;

  // protected
  CommonFacebook? get facebook;
  // protected
  CommonMessenger? get messenger;

  @override
  Future<bool> queryMeta(ID identifier) async {
    if (!isMetaQueryExpired(identifier)) {
      // query not expired yet
      Log.debug('meta query not expired yet: $identifier');
      return false;
    }
    Log.info('querying meta for: $identifier');
    var content = MetaCommand.query(identifier);
    var pair = await messenger?.sendContent(content,
      sender: null, receiver: Station.kAny, priority: 1,);
    return pair?.second != null;
  }

  @override
  Future<bool> queryDocuments(ID identifier, List<Document> documents) async {
    if (!isDocumentQueryExpired(identifier)) {
      // query not expired yet
      Log.debug('document query not expired yet: $identifier');
      return false;
    }
    DateTime? lastTime = await getLastDocumentTime(identifier, documents);
    Log.info('querying documents for: $identifier, last time: $lastTime');
    var content = DocumentCommand.query(identifier, lastTime);
    var pair = await messenger?.sendContent(content,
        sender: null, receiver: Station.kAny, priority: 1);
    return pair?.second != null;
  }

  @override
  Future<bool> queryMembers(ID identifier, List<ID> members) async {
    if (!isMembersQueryExpired(identifier)) {
      // query not expired yet
      Log.debug('members query not expired yet: $identifier');
      return false;
    }
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    DateTime? lastTime = await getLastGroupHistoryTime(identifier);
    Log.info('querying members for group: $identifier, last time: $lastTime');
    // build query command for group members
    var command = GroupCommand.query(identifier, lastTime);
    bool ok;
    // 1. check group bots
    ok = await queryMembersFromAssistants(command, sender: me, group: identifier);
    if (ok) {
      return true;
    }
    // 2. check administrators
    ok = await queryMembersFromAdministrators(command, sender: me, group: identifier);
    if (ok) {
      return true;
    }
    // 3. check group owner
    ok = await queryMembersFromOwner(command, sender: me, group: identifier);
    if (ok) {
      return true;
    }
    // all failed, try last active member
    Pair<InstantMessage, ReliableMessage?>? pair;
    ID? lastMember = _lastActiveMembers[identifier];
    if (lastMember != null) {
      Log.info('querying members from: $lastMember, group: $identifier');
      pair = await messenger?.sendContent(command, sender: me, receiver: lastMember, priority: 1);
    }
    Log.error('group not ready: $identifier');
    return pair?.second != null;
  }

  // protected
  Future<bool> queryMembersFromAssistants(QueryCommand command, {required ID sender, required ID group}) async {
    List<ID>? bots = await facebook?.getAssistants(group);
    if (bots == null || bots.isEmpty) {
      Log.warning('assistants not designated for group: $group');
      return false;
    }
    int success = 0;
    Pair<InstantMessage, ReliableMessage?>? pair;
    // querying members from bots
    Log.info('querying members from bots: $bots, group: $group');
    for (ID receiver in bots) {
      if (sender == receiver) {
        Log.warning('ignore cycled querying: $sender, group: $group');
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
    ID? lastMember = _lastActiveMembers[group];
    if (lastMember == null || bots.contains(lastMember)) {
      // last active member is a bot??
    } else {
      Log.info('querying members from: $lastMember, group: $group');
      await messenger?.sendContent(command, sender: sender, receiver: lastMember, priority: 1);
    }
    return true;
  }

  // protected
  Future<bool> queryMembersFromAdministrators(QueryCommand command, {required ID sender, required ID group}) async {
    ClientFacebook? barrack = facebook as ClientFacebook?;
    List<ID>? admins = await barrack?.getAdministrators(group);
    if (admins == null || admins.isEmpty) {
      Log.warning('administrators not found for group: $group');
      return false;
    }
    int success = 0;
    Pair<InstantMessage, ReliableMessage?>? pair;
    // querying members from admins
    Log.info('querying members from admins: $admins, group: $group');
    for (ID receiver in admins) {
      if (sender == receiver) {
        Log.warning('ignore cycled querying: $sender, group: $group');
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
    ID? lastMember = _lastActiveMembers[group];
    if (lastMember == null || admins.contains(lastMember)) {
      // last active member is an admin, already queried
    } else {
      Log.info('querying members from: $lastMember, group: $group');
      await messenger?.sendContent(command, sender: sender, receiver: lastMember, priority: 1);
    }
    return true;
  }

  // protected
  Future<bool> queryMembersFromOwner(QueryCommand command, {required ID sender, required ID group}) async {
    ID? owner = await facebook?.getOwner(group);
    if (owner == null) {
      Log.warning('owner not found for group: $group');
      return false;
    } else if (owner == sender) {
      Log.error('you are the owner of group: $group');
      return false;
    }
    Pair<InstantMessage, ReliableMessage?>? pair;
    // querying members from owner
    Log.info('querying members from owner: $owner, group: $group');
    pair = await messenger?.sendContent(command, sender: sender, receiver: owner, priority: 1);
    if (pair?.second == null) {
      // failed
      return false;
    }
    ID? lastMember = _lastActiveMembers[group];
    if (lastMember == null || lastMember == owner) {
      // last active member is the owner, already queried
    } else {
      Log.info('querying members from: $lastMember, group: $group');
      messenger?.sendContent(command, sender: sender, receiver: lastMember, priority: 1);
    }
    return true;
  }

}
