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
import 'package:lnc/lnc.dart';
import 'package:object_key/object_key.dart';

import '../group.dart';

///  Reset Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. reset group members
///      2. only group owner or assistant can reset group members
///
///      3. specially, if the group members info lost,
///         means you may not known who's the group owner immediately (and he may be not online),
///         so we accept the new members-list temporary, and find out who is the owner,
///         after that, we will send 'query' to the owner to get the newest members-list.
class ResetCommandProcessor extends GroupCommandProcessor {
  ResetCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is ResetCommand, 'reset command error: $content');
    ResetCommand command = content as ResetCommand;

    // 0. check command
    if (await isCommandExpired(command)) {
      // ignore expired command
      return [];
    }
    ID group = command.group!;
    List<ID> newMembers = getMembersFromCommand(command);
    if (newMembers.isEmpty) {
      return respondReceipt('Command error.', rMsg, group: group, extra: {
        'template': 'New member list is empty: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 1. check group
    ID? owner = await getOwner(group);
    List<ID> members = await getMembers(group);
    if (owner == null/* || members.isEmpty*/) {
      // TODO: query group bulletin document?
      return respondReceipt('Group empty.', rMsg, group: group, extra: {
        'template': 'Group empty: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    ID sender = rMsg.sender;
    List<ID> admins = await getAdministrators(group);
    bool isOwner = owner == sender;
    bool isAdmin = admins.contains(sender);

    // 2. check permission
    if (!isOwner && !isAdmin) {
      return respondReceipt('Permission denied.', rMsg, group: group, extra: {
        'template': 'Not allowed to reset members of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    // 2.1. check owner
    if (newMembers[0] != owner) {
      return respondReceipt('Permission denied.', rMsg, group: group, extra: {
        'template': 'Owner must be the first member of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    // 2.2. check admins
    bool expelAdmin = false;
    for (ID item in admins) {
      if (!newMembers.contains(item)) {
        expelAdmin = true;
        break;
      }
    }
    if (expelAdmin) {
      return respondReceipt('Permission denied.', rMsg, group: group, extra: {
        'template': 'Not allowed to expel administrator of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. try to save 'reset' command
    if (await updateResetCommandMessage(group: group, content: command, rMsg: rMsg)) {
      Log.info('updated "reset" command for group: $group');
    } else {
      // newer 'reset' command exists, drop this command
      return [];
    }

    // 4. do reset
    Pair<List<ID>, List<ID>> pair = await _resetMembers(group: group, oldMembers: members, newMembers: newMembers);
    List<ID> addList = pair.first;
    List<ID> removeList = pair.second;
    if (addList.isNotEmpty) {
      command['added'] = ID.revert(addList);
    }
    if (removeList.isNotEmpty) {
      command['removed'] = ID.revert(removeList);
    }

    // no need to response this group command
    return [];
  }

  Future<Pair<List<ID>, List<ID>>> _resetMembers({required ID group,
                                                  required List<ID> oldMembers,
                                                  required List<ID> newMembers}) async {
    List<ID> addList = [];
    List<ID> removeList = [];
    // build invited-list
    for (ID item in newMembers) {
      if (oldMembers.contains(item)) {
        continue;
      }
      addList.add(item);
    }
    // build expelled-list
    for (ID item in oldMembers) {
      if (newMembers.contains(item)) {
        continue;
      }
      removeList.add(item);
    }
    if (addList.isNotEmpty || removeList.isNotEmpty) {
      if (await saveMembers(newMembers, group)) {} else {
        assert(false, 'failed to save members in group: $group');
        addList.clear();
        removeList.clear();
      }
    }
    return Pair(addList, removeList);
  }

}
