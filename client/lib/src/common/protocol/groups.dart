/* license: https://mit-license.org
 *
 *  DIMP : Decentralized Instant Messaging Protocol
 *
 *                                Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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
 * ==============================================================================
 */
import 'dart:typed_data';

import 'package:dimsdk/dimsdk.dart';

import 'customized.dart';

// ignore_for_file: constant_identifier_names

///  Group Query Command: {
///      "type" : i2s(0xCC),
///      "sn"   : 123,
///      "time" : 123.456,
///
///      "app"  : "chat.dim.group",
///      "mod"  : "history",
///      "act"  : "query",
///
///      "group"     : "{GROUP_ID}",
///      "last_time" : 0,             // Last group history time for querying
///  }
abstract interface class GroupHistory {

  static const String APP = 'chat.dim.group';
  static const String MOD = 'history';

  static const String ACT_QUERY = 'query';

  //
  //  Factory method
  //

  /// QueryCommand is deprecated, use this method instead.
  static CustomizedContent queryGroupHistory(ID group, DateTime? lastTime) {
    var content = CustomizedContent.create(app: APP, mod: MOD, act: ACT_QUERY);
    content.group = group;
    if (lastTime != null) {
      // Last group history time for querying
      content.setDateTime('last_time', lastTime);
    }
    return content;
  }

}


///  Group Keys Command: {
///      "type" : i2s(0xCC),
///      "sn"   : 123,
///      "time" : 123.456,
///
///      "app"  : "chat.dim.group",
///      "mod"  : "keys",
///      "act"  : "query",   // "update", "request", "respond"
///
///      "group"  : "{GROUP_ID}",
///      "from"   : "{SENDER_ID}",
///      "to"     : ["{MEMBER_ID}", ],  // query for members
///      "digest" : "{KEY_DIGEST}",     // query with digest
///      "keys"   : {
///          "digest"      : "{KEY_DIGEST}",
///          "{MEMBER_ID}" : "{ENCRYPTED_KEY}",
///      }
///  }
abstract interface class GroupKeys {

  static const String APP = 'chat.dim.group';
  static const String MOD = 'keys';

  ///  Group Key Actions:
  ///
  ///     1. when group bot found new member, or key digest updated,
  ///        send a 'query' command to the message sender for new keys;
  ///
  ///     2. send all keys with digest to the group bot;
  ///
  ///     3. if a member received a group message with new key digest,
  ///        send a 'request' command to the group bot;
  ///
  ///     4. send new key to the group member.
  ///
  static const String ACT_QUERY   = 'query';    // 1. bot -> sender
  static const String ACT_UPDATE  = 'update';   // 2. sender -> bot
  static const String ACT_REQUEST = 'request';  // 3. member -> bot
  static const String ACT_RESPOND = 'respond';  // 4. bot -> member

  //
  //  Factory methods
  //

  static CustomizedContent create(String action, ID group, {
    required ID sender, // keys from this user
    List<ID>? members,  // query for members
    String? digest,     // query with digest
    Map? encodedKeys,   // update/respond keys (and digest)
  }) {
    assert(group.isGroup, 'group ID error: $group');
    assert(sender.isUser, 'user ID error: $sender');
    // 1. create group command
    var content = CustomizedContent.create(app: APP, mod: MOD, act: action);
    content.group = group;
    // 2. direction: sender -> members
    content.setString('from', sender);
    if (members != null) {
      content['to'] = ID.revert(members);
    }
    // 3. keys and digest
    if (encodedKeys != null) {
      content['keys'] = encodedKeys;
    } else if (digest != null) {
      content['digest'] = digest;
    }
    // OK
    return content;
  }

  // 1. bot -> sender
  /// Query group keys from sender
  static CustomizedContent queryGroupKeys(ID group, {
    required ID sender,
    required List<ID> members,
    String? digest,
  }) => create(ACT_QUERY, group, sender: sender, members: members, digest: digest);

  // 2. sender -> bot
  /// Update group keys from sender
  static CustomizedContent updateGroupKeys(ID group, {
    required ID sender,
    required Map encodedKeys,
  }) => create(ACT_UPDATE, group, sender: sender, encodedKeys: encodedKeys);

  // 3. member -> bot
  /// Request group key for this member
  static CustomizedContent requestGroupKey(ID group, {
    required ID sender,
    String? digest,
  }) => create(ACT_REQUEST, group, sender: sender, digest: digest);

  // 4. bot -> member
  /// Respond group key to member
  static CustomizedContent respondGroupKey(ID group, {
    required ID sender,
    required ID member,
    required Object encodedKey,
    required String digest,
  }) => create(ACT_RESPOND, group, sender: sender, encodedKeys: {
    'digest': digest,
    member.toString(): encodedKey,
  });

  //
  //  Key Digest
  //

  /// Get key digest
  static String digest(SymmetricKey password) {
    Uint8List key = password.data;                 // 32 bytes
    Uint8List suf = key.sublist(key.length >> 1);  // last 16 bytes
    Uint8List dig = MD5.digest(suf);               // 16 bytes
    String result = Base64.encode(dig);            // 24 chars
    return result.substring(result.length >> 1);   // last 12 chars
  }

}
