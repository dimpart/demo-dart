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

import '../group.dart';

///  Expel Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. remove group member(s)
///      2. only group owner or administrator can expel member
class ExpelCommandProcessor extends GroupCommandProcessor {
  ExpelCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is ExpelCommand, 'expel command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    Pair<ID?, List<Content>?> grpPair = await checkCommandExpired(command, rMsg);
    ID? group = grpPair.first;
    if (group == null) {
      // ignore expired command
      return grpPair.second ?? [];
    }
    Pair<List<ID>, List<Content>?> memPair = await checkCommandMembers(command, rMsg);
    List<ID> expelList = memPair.first;
    if (expelList.isEmpty) {
      // command error
      return memPair.second ?? [];
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
    bool canExpel = isOwner || isAdmin;
    if (!canExpel) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to expel member from group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    // 2.1. check owner
    if (expelList.contains(owner)) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to expel owner of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    // 2.2. check admins
    bool expelAdmin = false;
    for (ID item in admins) {
      if (expelList.contains(item)) {
        expelAdmin = true;
        break;
      }
    }
    if (expelAdmin) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to expel administrator of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. do expel
    Pair<List<ID>, List<ID>> pair = calculateExpelled(members: members, expelList: expelList);
    List<ID> newMembers = pair.first;
    List<ID> removeList = pair.second;
    if (removeList.isEmpty) {
      // nothing changed
    } else if (await saveMembers(group, newMembers)) {
      command['removed'] = ID.revert(removeList);
    }

    // no need to response this group command
    return [];
  }

  // protected
  static Pair<List<ID>, List<ID>> calculateExpelled({required List<ID> members, required List<ID> expelList}) {
    List<ID> newMembers = [];
    List<ID> removeList = [];
    for (ID item in members) {
      if (expelList.contains(item)) {
        removeList.add(item);
      } else {
        newMembers.add(item);
      }
    }
    return Pair(newMembers, removeList);
  }

}
