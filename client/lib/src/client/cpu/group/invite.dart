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

///  Invite Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. add new member(s) to the group
///      2. any member can invite new member
///      3. invited by ordinary member should be reviewed by owner/administrator
class InviteCommandProcessor extends GroupCommandProcessor {
  InviteCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is InviteCommand, 'invite command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    Pair<ID?, List<Content>?> pair = await checkCommandExpired(command, rMsg);
    ID? group = pair.first;
    if (group == null) {
      // ignore expired command
      return pair.second ?? [];
    }
    Pair<List<ID>, List<Content>?> pair1 = await checkCommandMembers(command, rMsg);
    List<ID> inviteList = pair1.first;
    if (inviteList.isEmpty) {
      // command error
      return pair1.second ?? [];
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
    bool isMember = members.contains(sender);

    // 2. check permission
    if (!isMember) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to invite member into group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    bool canReset = isOwner || isAdmin;

    // 3. do invite
    Pair<List<ID>, List<ID>> memPair = calculateInvited(members: members, inviteList: inviteList);
    List<ID> newMembers = memPair.first;
    List<ID> addedList = memPair.second;
    if (addedList.isEmpty) {
      // maybe those users are already become members,
      // but if it can still receive an 'invite' command here,
      // we should respond the sender with the newest membership again.
      User? user = await facebook?.currentUser;
      if (!canReset && owner == user?.identifier) {
        // invited by ordinary member, and I am the owner, so
        // send a 'reset' command to update members in the sender's memory
        bool ok = await sendResetCommand(group: group, members: newMembers, receiver: sender);
        assert(ok, 'failed to send "reset" command for group: $group => $sender');
      }
    } else if (!canReset) {
      // invited by ordinary member
      // add 'invite' application for waiting review
      if (await attachApplication(command, rMsg)) {
        command['added'] = ID.revert(addedList);
      } else {
        assert(false, 'failed to add "invite" application for group: $group');
      }
    } else if (await saveMembers(group, newMembers)) {
      // invited by owner or admin, so
      // append the new members directly.
      command['added'] = ID.revert(addedList);
    } else {
      assert(false, 'failed to save members for group: $group');
    }

    // no need to response this group command
    return [];
  }

  // protected
  static Pair<List<ID>, List<ID>> calculateInvited({required List<ID> members, required List<ID> inviteList}) {
    List<ID> newMembers = [...members];
    List<ID> addedList = [];
    for (ID item in inviteList) {
      if (newMembers.contains(item)) {
        continue;
      }
      newMembers.add(item);
      addedList.add(item);
    }
    return Pair(newMembers, addedList);
  }

}
