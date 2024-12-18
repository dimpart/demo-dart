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

import '../common/facebook.dart';
import '../common/messenger.dart';

import 'delegate.dart';


class AdminManager extends TripletsHelper {
  AdminManager(super.delegate);

  ///  Update 'administrators' in bulletin document
  ///  (broadcast new document to all members and neighbor station)
  ///
  /// @param group     - group ID
  /// @param newAdmins - administrator list
  /// @return false on error
  Future<bool> updateAdministrators(List<ID> newAdmins, {required ID group}) async {
    assert(group.isGroup, 'group ID error: $group');
    CommonFacebook? barrack = facebook;
    assert(barrack != null, 'facebook not ready');

    //
    //  0. get current user
    //
    User? user = await barrack?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    SignKey? sKey = await barrack?.getPrivateKeyForVisaSignature(me);
    assert(sKey != null, 'failed to get sign key for current user: $me');

    //
    //  1. check permission
    //
    bool isOwner = await delegate.isOwner(me, group: group);
    if (!isOwner) {
      // assert(false, 'cannot update administrators for group: $group, $me');
      return false;
    }

    //
    //  2. update document
    //
    Bulletin? bulletin = await delegate.getBulletin(group);
    if (bulletin == null) {
      // TODO: create new one?
      assert(false, 'failed to get group document: $group, owner: $me');
      return false;
    } else {
      // clone for modifying
      Document? clone = Document.parse(bulletin.copyMap(false));
      if (clone is Bulletin) {
        bulletin = clone;
      } else {
        assert(false, 'bulletin error: $bulletin, $group');
        return false;
      }
    }
    bulletin.setProperty('administrators', ID.revert(newAdmins));
    var signature = sKey == null ? null : bulletin.sign(sKey);
    if (signature == null) {
      assert(false, 'failed to sign document for group: $group, owner: $me');
      return false;
    } else if (!await delegate.saveDocument(bulletin)) {
      assert(false, 'failed to save document for group: $group');
      return false;
    } else {
      logInfo('group document updated: $group');
    }

    //
    //  3. broadcast bulletin document
    //
    return broadcastGroupDocument(bulletin);
  }

  /// Broadcast group document
  Future<bool> broadcastGroupDocument(Bulletin doc) async {
    CommonFacebook? barrack = facebook;
    CommonMessenger? transceiver = messenger;
    assert(barrack != null && transceiver != null, 'facebook messenger not ready: $barrack, $transceiver');

    //
    //  0. get current user
    //
    User? user = await barrack?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    //
    //  1. create 'document' command, and send to current station
    //
    ID group = doc.identifier;
    Meta? meta = await barrack?.getMeta(group);
    Command content = DocumentCommand.response(group, meta, doc);
    transceiver?.sendContent(content, sender: me, receiver: Station.kAny, priority: 1);

    //
    //  2. check group bots
    //
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // group bots exist, let them to deliver to all other members
      for (ID item in bots) {
        if (me == item) {
          assert(false, 'should not be a bot here: $me');
          continue;
        }
        transceiver?.sendContent(content, sender: me, receiver: item, priority: 1);
      }
      return true;
    }

    //
    //  3. broadcast to all members
    //
    List<ID> members = await delegate.getMembers(group);
    if (members.isEmpty) {
      assert(false, 'failed to get group members: $group');
      return false;
    }
    for (ID item in members) {
      if (me == item) {
        logInfo('skip cycled message: $item, $group');
        continue;
      }
      transceiver?.sendContent(content, sender: me, receiver: item, priority: 1);
    }
    return true;
  }

}
