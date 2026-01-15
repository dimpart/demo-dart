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
import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/log.dart';
import 'package:stargate/skywalker.dart';

import '../common/dbi/account.dart';
import '../common/mkm/utils.dart';
import '../common/facebook.dart';
import '../common/messenger.dart';
import '../common/session.dart';


class GroupDelegate extends TwinsHelper implements GroupDataSource {
  GroupDelegate(CommonFacebook facebook, CommonMessenger messenger)
      : super(facebook, messenger) {
    _GroupBotsManager().messenger = messenger;
  }

  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  Archivist? get archivist => facebook?.archivist;

  Future<String> buildGroupName(List<ID> members) async {
    assert(members.isNotEmpty, 'members should not be empty here');
    CommonFacebook facebook = this.facebook!;
    String text = await facebook.getName(members.first);
    String nickname;
    for (int i = 1; i < members.length; ++i) {
      nickname = await facebook.getName(members[i]);
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

  Future<bool> saveDocument(Document doc, ID did) async =>
      await archivist!.saveDocument(doc, did);

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

  Future<bool> saveMembers(List<ID> members, ID group) async =>
      await facebook!.saveMembers(members, group);

  //
  //  Group Assistants
  //

  Future<List<ID>> getAssistants(ID group) async =>
      await _GroupBotsManager().getAssistants(group);

  Future<ID?> getFastestAssistant(group) async =>
      await _GroupBotsManager().getFastestAssistant(group);

  void setCommonAssistants(List<ID> bots) =>
      _GroupBotsManager().setCommonAssistants(bots);

  bool updateRespondTime(ReceiptCommand content, Envelope envelope) =>
      _GroupBotsManager().updateRespondTime(content, envelope);

  //
  //  Administrators
  //

  Future<List<ID>> getAdministrators(ID group) async =>
      await facebook!.getAdministrators(group);

  Future<bool> saveAdministrators(List<ID> admins, ID group) async =>
      await facebook!.saveAdministrators(admins, group);

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
    return MetaUtils.matchPublicKey(mMeta.publicKey, gMeta);
  }

  Future<bool> isOwner(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    ID? owner = await getOwner(group);
    if (owner != null) {
      return owner == user;
    }
    if (group.type == EntityType.GROUP) {
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
  AccountDBI? get database => facebook?.database;

}


class _GroupBotsManager extends Runner with Logging {
  factory _GroupBotsManager() => _instance;
  static final _GroupBotsManager _instance = _GroupBotsManager._internal();
  _GroupBotsManager._internal() : super(Runner.INTERVAL_SLOW) {
    /* await */run();
  }

  List<ID> _commonAssistants = [];

  Set<ID> _candidates = {};                    // bot IDs to be check
  final Map<ID, Duration> _respondTimes = {};  // bot IDs with respond time

  WeakReference<CommonMessenger>? _transceiver;

  CommonMessenger? get messenger => _transceiver?.target;
  set messenger(CommonMessenger? delegate) =>
      _transceiver = delegate == null ? null : WeakReference(delegate);

  CommonFacebook? get facebook => messenger?.facebook;

  /// When received receipt command from the bot
  /// update the speed of this bot.
  bool updateRespondTime(ReceiptCommand content, Envelope envelope) {
    // var app = content['app'];
    // app ??= content['app_id'];
    // if (app != 'chat.dim.group.assistant') {
    //   return false;
    // }
    //
    //  1. check sender
    //
    ID sender = envelope.sender;
    if (sender.type != EntityType.BOT) {
      return false;
    }
    ID? originalReceiver = content.originalEnvelope?.receiver;
    if (originalReceiver != sender) {
      assert(originalReceiver?.isBroadcast == true, 'sender error: $sender, $originalReceiver');
      return false;
    }
    //
    //  2. check send time
    //
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
    //
    //  3. check duration
    //
    Duration? cached = _respondTimes[sender];
    if (cached != null && cached <= duration) {
      return false;
    }
    _respondTimes[sender] = duration;
    return true;
  }

  /// When received new config from current Service Provider,
  /// set common assistants of this SP.
  void setCommonAssistants(List<ID> bots) {
    logInfo('add group bots: $bots into $_candidates');
    _candidates.addAll(bots);
    _commonAssistants = bots;
  }

  Future<List<ID>> getAssistants(ID group) async {
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
    if (bots.isEmpty) {
      logWarning('group bots not found: $group');
      return null;
    }
    ID? prime;
    Duration? primeDuration;
    Duration? duration;
    for (ID ass in bots) {
      duration = _respondTimes[ass];
      if (duration == null) {
        logInfo('group bot not respond yet, ignore it: $ass, $group');
        continue;
      } else if (primeDuration == null) {
        // first responded bot
      } else if (primeDuration < duration) {
        logInfo('this bot $ass is slower than $prime, skip it, $group');
        continue;
      }
      prime = ass;
      primeDuration = duration;
    }
    if (prime == null) {
      prime = bots.first;
      logInfo('no bot responded, take the first one: $bots, $group');
    } else {
      logInfo('got the fastest bot with respond time: $primeDuration, $prime, $group');
    }
    return prime;
  }

  @override
  Future<bool> process() async {
    CommonMessenger? transceiver = messenger;
    if (transceiver == null) {
      return false;
    }
    //
    //  1. check session
    //
    Session session = transceiver.session;
    if (session.sessionKey == null || !session.isActive) {
      // not login yet
      return false;
    }
    //
    //  2. get visa
    //
    ID me;
    Visa? visa;
    try {
      User? user = await facebook?.currentUser;
      if (user == null) {
        return false;
      }
      me = user.identifier;
      visa = DocumentUtils.lastVisa(await user.documents);
      if (visa == null) {
        logError('failed to get visa: $me');
        return false;
      }
    } catch (e, st) {
      logError('failed to get current user: $e, $st');
      return false;
    }
    var checker = facebook?.entityChecker;
    //
    //  3. check candidates
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
        await checker?.sendDocuments(me, [visa], recipients: [item]);
      } catch (e, st) {
        logError('failed to query assistant: $item, $e, $st');
      }
    }
    return false;
  }

}
