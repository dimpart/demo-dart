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
import 'dart:typed_data';

import 'package:dimp/dimp.dart';
import 'package:object_key/object_key.dart';

import '../group.dart';

///  Resign Group Admin Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. remove the sender from administrators of the group
///      2. administrator can be hired/fired by owner only
class ResignCommandProcessor extends GroupCommandProcessor {
  ResignCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is ResignCommand, 'resign command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    Pair<ID?, List<Content>?> pair = await checkCommandExpired(command, rMsg);
    ID? group = pair.first;
    if (group == null) {
      // ignore expired command
      return pair.second ?? [];
    }

    // 1. check group
    Triplet<ID?, List<ID>, List<Content>?> trip = await checkGroupMembers(command, rMsg);
    ID? owner = trip.first;
    List<ID> members = trip.second;
    if (owner == null || members.isEmpty) {
      return trip.third ?? [];
    }
    String text;

    ID sender = rMsg.sender;
    List<ID> admins = await getAdministrators(group);
    bool isOwner = owner == sender;
    bool isAdmin = admins.contains(sender);

    // 2. check permission
    if (isOwner) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Owner cannot resign from group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. do resign
    if (isAdmin) {
      // admin do exist, remove it and update database
      admins = [...admins];
      admins.remove(sender);
      if (await saveAdministrators(group, admins)) {
        command['removed'] = [sender.toString()];
      } else {
        assert(false, 'failed to save administrators for group: $group');
      }
    }

    // 4. update bulletin property: 'administrators'
    User? user = await facebook?.currentUser;
    assert(user != null, 'failed to get current user');
    ID? me = user?.identifier;
    if (owner == me) {
      // maybe the bulletin in the owner's storage not contains this administrator,
      // but if it can still receive a resign command here, then
      // the owner should update the bulletin and send it out again.
      bool ok = await _refreshAdministrators(group: group, owner: owner, admins: admins);
      assert(ok, 'failed to refresh admins for group: $group');
    } else if (await attachApplication(command, rMsg)) {
      // add 'resign' application for querying by other members,
      // if thw owner wakeup, it will broadcast a new bulletin document
      // with the newest administrators, and this application will be erased.
    } else {
      assert(false, 'failed to add "resign" application for group: $group');
    }

    // no need to response this group command
    return [];
  }

  Future<bool> _refreshAdministrators({required ID group, required ID owner, required List<ID> admins}) async {
    // 1. update bulletin
    Document? bulletin = await _updateAdministrators(group: group, owner: owner, admins: admins);
    if (bulletin == null) {
      assert(false, 'failed to update administrators for group: $group');
      return false;
    } else if (await facebook!.saveDocument(bulletin)) {
      // document updated
    } else {
      assert(false, 'failed to save document for group: $group');
      return false;
    }
    Meta? meta = await facebook?.getMeta(group);
    Content content = DocumentCommand.response(group, meta, bulletin);
    // 2. check assistants
    List<ID> bots = await getAssistants(group);
    if (bots.isEmpty) {
      // TODO: broadcast to all members?
      return true;
    }
    // 3. broadcast to all group assistants
    for (ID receiver in bots) {
      if (owner == receiver) {
        assert(false, 'group bot should not be owner: $owner, group: $group');
        continue;
      }
      messenger?.sendContent(content, sender: owner, receiver: receiver, priority: 1);
    }
    return true;
  }

  Future<Document?> _updateAdministrators({required ID group, required ID owner, required List<ID> admins}) async {
    // get document & sign key
    Document? bulletin = await facebook?.getDocument(group, '*');
    SignKey? sKey = await facebook?.getPrivateKeyForVisaSignature(owner);
    if (bulletin == null || sKey == null) {
      assert(false, 'failed to get document & sign key for group: $group, owner: $owner');
      return null;
    }
    // assert(bulletin is Bulletin, 'group document error: $group');
    bulletin.setProperty('administrators', ID.revert(admins));
    Uint8List? signature = bulletin.sign(sKey);
    assert(signature != null, 'failed to sign bulletin for group: $group');
    return bulletin;
  }

}
