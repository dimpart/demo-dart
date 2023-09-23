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
    if (await isCommandExpired(command)) {
      // ignore expired command
      return [];
    }
    ID group = command.group!;
    String text;

    // 1. check group
    ID? owner = await getOwner(group);
    List<ID> members = await getMembers(group);
    if (owner == null || members.isEmpty) {
      // TODO: query group members?
      text = 'Group empty.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Group empty: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 2. check permission
    ID sender = rMsg.sender;
    if (owner == sender) {
      text = 'Permission denied.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Owner cannot resign from group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    List<ID> admins = await getAdministrators(group);

    // 3. do resign
    admins = [...admins];
    bool isAdmin = admins.contains(sender);
    if (isAdmin) {
      // admin do exist, remove it and update database
      admins.remove(sender);
      bool ok = await saveAdministrators(admins, group);
      assert(ok, 'failed to save administrators for group: $group');
    }

    // 4. update bulletin property: 'administrators'
    User? user = await facebook?.currentUser;
    assert(user != null, 'failed to get current user');
    ID me = user!.identifier;
    if (owner == me) {
      // maybe the bulletin in the owner's storage not contains this administrator,
      // but if it can still receive a resign command here, then
      // the owner should update the bulletin and send it out again.
      bool ok = await _refreshAdministrators(group: group, owner: owner, admins: admins);
      assert(ok, 'failed to refresh admins for group: $group');
    } else {
      // add 'resign' application for waiting owner to update
      bool ok = await addApplication(command, rMsg);
      assert(ok, 'failed to add "resign" application for group: $group');
    }
    if (!isAdmin) {
      text = 'Permission denied.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Not a administrator of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
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
    } else if (await facebook!.saveDocument(bulletin)) {} else {
      assert(false, 'failed to save document for group: $group');
      return false;
    }
    Meta? meta = await facebook?.getMeta(group);
    Content content = DocumentCommand.response(group, meta, bulletin);
    // 2. send to assistants
    List<ID> bots = await getAssistants(group);
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
    // update document property
    Document? bulletin = await facebook?.getDocument(group, '*');
    if (bulletin == null) {
      assert(false, 'failed to get document for group: $group');
      return null;
    }
    assert(bulletin is Bulletin, 'group document error: $group');
    bulletin.setProperty('administrators', ID.revert(admins));
    // sign document
    SignKey? sKey = await facebook?.getPrivateKeyForVisaSignature(owner);
    if (sKey == null) {
      assert(false, 'failed to get sign key for group owner: $owner, group: $group');
      return null;
    }
    Uint8List? signature = bulletin.sign(sKey);
    assert(signature != null, 'failed to sign bulletin for group: $group');
    return bulletin;
  }

}
