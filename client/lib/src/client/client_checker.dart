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
  Future<bool> queryMeta(ID identifier, {
    required List<ID> respondents
  }) async {
    Content content = MetaCommand.query(identifier);
    logInfo('querying meta for: $identifier << $respondents');
    // Send content to all respondents if expired
    return await _sendContentIfExpired(content, respondents, isExpired: (receiver) {
      bool expired = isMetaQueryExpired(identifier, respondent: receiver);
      if (!expired) {
        logInfo('meta query not expired yet: $identifier << $receiver');
      }
      return expired;
    });
  }

  @override
  Future<bool> queryDocuments(ID identifier, DateTime? lastTime, {
    required List<ID> respondents
  }) async {
    Content content = DocumentCommand.query(identifier, lastTime);
    logInfo('querying documents for: $identifier, last time: $lastTime << $respondents');
    // Send content to all respondents if expired
    return await _sendContentIfExpired(content, respondents, isExpired: (receiver) {
      bool expired = isDocumentQueryExpired(identifier, respondent: receiver);
      if (!expired) {
        logInfo('document query not expired yet: $identifier << $receiver');
      }
      return expired;
    });
  }

  @override
  Future<bool> queryMembers(ID group, DateTime? lastTime, {
    required List<ID> respondents
  }) async {
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
    // Send content to all respondents if expired
    return await _sendContentIfExpired(content, respondents, isExpired: (receiver) {
      bool expired = isMembersQueryExpired(group, respondent: receiver);
      if (!expired) {
        logInfo('members query not expired yet: $group << $receiver');
      }
      return expired;
    });
  }

  @override
  Future<bool> sendMeta(ID identifier, Meta meta, {
    required List<ID> recipients
  }) async {
    Content content = MetaCommand.response(identifier, meta);
    logDebug('sending meta: $identifier => $recipients');
    // Send content to all recipients if expired
    return await _sendContentIfExpired(content, recipients, isExpired: (receiver) {
      bool expired = isMetaResponseExpired(identifier, recipient: receiver);
      if (!expired) {
        logInfo('meta response not expired yet: $identifier -> $receiver');
      }
      return expired;
    });
  }

  @override
  Future<bool> sendDocuments(ID identifier, List<Document> docs, {bool force = false,
    required List<ID> recipients
  }) async {
    Meta? meta = await facebook?.getMeta(identifier);
    Content content = DocumentCommand.response(identifier, meta, docs);
    logInfo('sending document: $identifier => $recipients');
    // Send content to all recipients if expired
    return await _sendContentIfExpired(content, recipients, isExpired: (receiver) {
      bool expired = isDocsResponseExpired(identifier, recipient: receiver, force: force);
      if (!expired) {
        logInfo('documents response not expired yet: $identifier -> $receiver');
      }
      return expired;
    });
  }

  @override
  Future<bool> sendHistories(ID group, List<ReliableMessage> messages, {
    required List<ID> recipients
  }) async {
    Content content = ForwardContent.create(secrets: messages);
    logInfo('sending group histories: $group => $recipients');
    // Send content to all recipients if expired
    return await _sendContentIfExpired(content, recipients, isExpired: (receiver) {
      bool expired = isHisResponseExpired(group, recipient: receiver);
      if (!expired) {
        logInfo('group histories response not expired yet: $group -> $receiver');
      }
      return expired;
    });
  }

  /// Send content to all recipients if expired
  Future<bool> _sendContentIfExpired(Content content, List<ID> recipients, {
    required bool Function(ID receiver) isExpired,
  }) async {
    Transmitter? transmitter = messenger;
    if (transmitter == null) {
      logWarning('messenger not ready yet');
      return false;
    }
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    int success = 0;
    Pair<InstantMessage, ReliableMessage?> pair;
    for (ID receiver in recipients) {
      if (receiver == me) {
        logWarning('ignore cycled responding: $receiver');
        continue;
      } else if (!isExpired(receiver)) {
        // response not expired yet
        continue;
      }
      pair = await transmitter.sendContent(content, sender: me, receiver: receiver, priority: 1);
      if (pair.second != null) {
        success += 1;
      }
    }
    return success > 0;
  }

}
