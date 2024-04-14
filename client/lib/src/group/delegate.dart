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
import 'package:lnc/log.dart';
import 'package:startrek/skywalker.dart';

import '../client/archivist.dart';
import '../client/facebook.dart';
import '../common/archivist.dart';
import '../common/facebook.dart';
import '../common/messenger.dart';
import '../common/session.dart';
import '../common/dbi/account.dart';


class GroupDelegate extends TwinsHelper implements GroupDataSource {
  GroupDelegate(CommonFacebook facebook, CommonMessenger messenger)
      : super(facebook, messenger) {
    _GroupBotsManager().setMessenger(messenger);
  }

  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  Future<String> buildGroupName(List<ID> members) async {
    assert(members.isNotEmpty, 'members should not be empty here');
    CommonFacebook barrack = facebook!;
    String text = await barrack.getName(members.first);
    String nickname;
    for (int i = 1; i < members.length; ++i) {
      nickname = await barrack.getName(members[i]);
      if (nickname.isEmpty) {
        continue;
      }
      text += ', $nickname';
      if (text.length > 32) {
        return '${text.substring(0, 28)} ...';
      }
    }
    return text;
  }

  //
  //  Entity DataSource
  //

  @override
  Future<Meta?> getMeta(ID identifier) async =>
      await facebook?.getMeta(identifier);

  @override
  Future<List<Document>> getDocuments(ID identifier) async =>
      await facebook!.getDocuments(identifier);

  Future<Bulletin?> getBulletin(ID group) async =>
      await facebook?.getBulletin(group);

  Future<bool> saveDocument(Document doc) async =>
      await facebook!.saveDocument(doc);

  //
  //  Group DataSource
  //

  @override
  Future<ID?> getFounder(ID group) async =>
      await facebook?.getFounder(group);

  @override
  Future<ID?> getOwner(ID group) async =>
      await facebook?.getOwner(group);

  @override
  Future<List<ID>> getMembers(ID group) async =>
      await facebook!.getMembers(group);

  Future<bool> saveMembers(ID group, List<ID> members) async =>
      await (facebook as ClientFacebook).saveMembers(members, group);

  //
  //  Group Assistants
  //

  @override
  Future<List<ID>> getAssistants(ID group) async =>
      await _GroupBotsManager().getAssistants(group) ?? [];

  Future<ID?> getFastestAssistant(ID group) async =>
      await _GroupBotsManager().getFastestAssistant(group);

  void setCommonAssistants(List<ID> bots) =>
      _GroupBotsManager().setCommonAssistants(bots);

  bool updateRespondTime(ReceiptCommand content, Envelope envelope) =>
      _GroupBotsManager().updateRespondTime(content, envelope);

  //
  //  Administrators
  //

  Future<List<ID>> getAdministrators(ID group) async =>
      await (facebook as ClientFacebook).getAdministrators(group);

  Future<bool> saveAdministrators(ID group, List<ID> admins) async =>
      await (facebook as ClientFacebook).saveAdministrators(admins, group);

  //
  //  Membership
  //

  Future<bool> isFounder(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    ID? founder = await getFounder(group);
    if (founder != null) {
      return founder == user;
    }
    // check member's public key with group's meta.key
    Meta? gMeta = await getMeta(group);
    Meta? mMeta = await getMeta(user);
    if (gMeta == null || mMeta == null) {
      assert(false, 'failed to get meta for group: $group, user: $user');
      return false;
    }
    return gMeta.matchPublicKey(mMeta.publicKey);
  }

  Future<bool> isOwner(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    ID? owner = await getOwner(group);
    if (owner != null) {
      return owner == user;
    }
    if (group.type == EntityType.kGroup) {
      // this is a polylogue
      return await isFounder(user, group: group);
    }
    throw Exception('only Polylogue so far');
  }

  Future<bool> isMember(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    List<ID> members = await getMembers(group);
    return members.contains(user);
  }

  Future<bool> isAdministrator(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    List<ID> admins = await getAdministrators(group);
    return admins.contains(user);
  }

  Future<bool> isAssistant(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    List<ID> bots = await getAssistants(group);
    return bots.contains(user);
  }

}


// protected
abstract class TripletsHelper with Logging {
  TripletsHelper(this.delegate);

  // protected
  final GroupDelegate delegate;

  // protected
  CommonFacebook? get facebook => delegate.facebook;

  // protected
  CommonMessenger? get messenger => delegate.messenger;

  // protected
  CommonArchivist? get archivist => facebook?.archivist;

  // protected
  AccountDBI? get database => facebook?.archivist.database;

}


class _GroupBotsManager extends Runner with Logging {
  factory _GroupBotsManager() => _instance;
  static final _GroupBotsManager _instance = _GroupBotsManager._internal();
  _GroupBotsManager._internal() : super(Runner.intervalSlow) {
    /* await */run();
  }

  List<ID>? _commonAssistants;

  CommonMessenger? _transceiver;

  Set<ID> _candidates = {};                    // group IDs to be check
  final Map<ID, Duration> _respondTimes = {};  // group IDs with respond time

  void setMessenger(CommonMessenger messenger) => _transceiver = messenger;

  /// When received receipt command from the bot
  /// update the speed of this bot.
  bool updateRespondTime(ReceiptCommand content, Envelope envelope) {
    // 1. check sender
    ID sender = envelope.sender;
    if (sender.type != EntityType.kBot) {
      return false;
    }
    ID? originalReceiver = content.originalEnvelope?.receiver;
    if (originalReceiver != sender) {
      assert(false, 'sender error: $sender, $originalReceiver');
      return false;
    }
    // 2. check send time
    DateTime? time = content.originalEnvelope?.time;
    if (time == null) {
      assert(false, 'original time not found: $content');
      return false;
    }
    Duration duration = DateTime.now().difference(time);
    if (duration.inMicroseconds <= 0) {
      assert(false, 'receipt time error: $time');
      return false;
    }
    // 3. check duration
    Duration? cached = _respondTimes[sender];
    if (cached != null && cached.inMicroseconds <= duration.inMicroseconds) {
      return false;
    }
    _respondTimes[sender] = duration;
    return true;
  }

  /// When received new config from current Service Provider,
  /// set common assistants of this SP.
  void setCommonAssistants(List<ID> bots) {
    _candidates.addAll(bots);
    _commonAssistants = bots;
  }

  Future<List<ID>?> getAssistants(ID group) async {
    CommonFacebook? facebook = _transceiver?.facebook;
    List<ID>? bots = await facebook?.getAssistants(group);
    if (bots == null || bots.isEmpty) {
      return _commonAssistants;
    }
    _candidates.addAll(bots);
    return bots;
  }

  /// Get the fastest group bot
  Future<ID?> getFastestAssistant(ID group) async {
    List<ID>? bots = await getAssistants(group);
    if (bots == null || bots.isEmpty) {
      logWarning('group bots not found: $group');
      return null;
    }
    ID? prime;
    Duration? primeDuration;
    Duration? duration;
    for (ID ass in bots) {
      duration = _respondTimes[ass];
      if (duration == null) {
        logInfo('group bot not respond yet, ignore it: $ass');
        continue;
      } else if (primeDuration != null && primeDuration < duration) {
        logInfo('this bot $ass is slower than $prime, skip it.');
        continue;
      }
      prime = ass;
      primeDuration = primeDuration;
    }
    if (prime != null) {
      logInfo('got the fastest bot with respond time: $primeDuration, $prime');
    }
    return prime;
  }

  @override
  Future<bool> process() async {
    //
    //  1. check session
    //
    Session? session = _transceiver?.session;
    if (session == null || session.key == null || !session.isActive) {
      // not login yet
      return false;
    }
    //
    //  2. get visa
    //
    Visa? visa;
    try {
      User? me = await _transceiver?.facebook.currentUser;
      visa = await me?.visa;
      if (visa == null) {
        logError('failed to get visa: $me');
        return false;
      }
    } catch (e, st) {
      logError('failed to get current user: $e, $st');
      return false;
    }
    //
    //  3. get archivist
    //
    CommonArchivist? archivist = _transceiver?.facebook.archivist;
    if (archivist is! ClientArchivist) {
      assert(false, 'archivist error: $archivist');
      return false;
    }
    //
    //  4. check candidates
    //
    Set<ID> bots = _candidates;
    _candidates = {};
    for (ID item in bots) {
      if (_respondTimes[item] != null) {
        // no need to check again
        logInfo('group bot already responded: $item');
        continue;
      }
      // no respond yet, try to push visa to the bot
      try {
        await archivist.sendDocument(visa, item);
      } catch (e, st) {
        logError('failed to query assistant: $item, $e, $st');
      }
    }
    return false;
  }

}
