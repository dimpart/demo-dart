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
import 'package:lnc/log.dart';

import 'dbi/account.dart';
import 'utils/checkers.dart';

abstract class EntityChecker with Logging {
  // ignore_for_file: non_constant_identifier_names

  /// each query will be expired after 10 minutes
  static Duration QUERY_EXPIRES = Duration(minutes: 10);

  /// each respond will be expired after 10 minutes
  static Duration RESPOND_EXPIRES = Duration(minutes: 10);

  /// query checkers
  final FrequencyChecker<String> _metaQueries    = FrequencyChecker(QUERY_EXPIRES);
  final FrequencyChecker<String> _docsQueries    = FrequencyChecker(QUERY_EXPIRES);
  final FrequencyChecker<String> _membersQueries = FrequencyChecker(QUERY_EXPIRES);

  /// response checker
  final FrequencyChecker<String> _metaResponses  = FrequencyChecker(RESPOND_EXPIRES);
  final FrequencyChecker<String> _docsResponses  = FrequencyChecker(RESPOND_EXPIRES);

  /// recent time checkers
  final RecentTimeChecker<ID> _lastDocumentTimes = RecentTimeChecker();
  final RecentTimeChecker<ID> _lastHistoryTimes  = RecentTimeChecker();

  /// group => member
  final Map<ID, ID> _lastActiveMembers = {};

  // protected
  final AccountDBI database;

  EntityChecker(this.database);

  // protected
  bool isMetaQueryExpired(ID identifier, {required ID respondent}) =>
      _metaQueries.isExpired('$identifier<<$respondent');
  bool isDocumentQueryExpired(ID identifier, {required ID respondent}) =>
      _docsQueries.isExpired('$identifier<<$respondent');
  bool isMembersQueryExpired(ID identifier, {required ID respondent})  =>
      _membersQueries.isExpired('$identifier<<$respondent');

  bool isMetaResponseExpired(ID identifier, {required ID recipient}) =>
      _metaResponses.isExpired('$identifier<<$recipient');
  bool isDocsResponseExpired(ID identifier, {required ID recipient, bool force = false}) =>
      _docsResponses.isExpired('$identifier<<$recipient', force: force);

  /// Set last active member for group
  void setLastActiveMember(ID member, {required ID group}) =>
      _lastActiveMembers[group] = member;
  // protected
  ID? getLastActiveMember({required ID group}) => _lastActiveMembers[group];

  /// Update 'SDT' - Sender Document Time
  bool setLastDocumentTime(DateTime current, ID identifier) =>
      _lastDocumentTimes.setLastTime(identifier, current);

  /// Update 'GHT' - Group History Time
  bool setLastGroupHistoryTime(DateTime current, ID group) =>
      _lastHistoryTimes.setLastTime(group, current);

  //
  //  Meta
  //

  ///  Check meta for querying
  ///
  /// @param identifier - entity ID
  /// @param meta       - exists meta
  /// @param sender     - message sender
  /// @return ture on querying
  Future<bool> checkMeta(ID identifier, Meta? meta, {ID? sender}) async {
    if (!needsQueryMeta(identifier, meta)) {
      // no need to query meta again
      return false;
    }
    // send command to ['station@anywhere', sender]
    List<ID> respondents = [Station.ANY];
    if (sender != null) {
      assert(sender != Station.ANY, 'sender error: $sender');
      respondents.add(sender);
    }
    return await queryMeta(identifier, respondents: respondents);
  }

  ///  check whether need to query meta
  // protected
  bool needsQueryMeta(ID identifier, Meta? meta) {
    if (identifier.isBroadcast) {
      // broadcast entity has no meta to query
      return false;
    } else if (meta == null) {
      // meta not found, sure to query
      return true;
    }
    bool matched = MetaUtils.matchIdentifier(identifier, meta);
    assert(matched, 'meta not match: $identifier, $meta');
    return !matched;
  }

  //
  //  Documents
  //

  ///  Check documents for querying/updating
  ///
  /// @param identifier - entity ID
  /// @param documents  - exist document
  /// @param sender     - message sender
  /// @return true on querying
  Future<bool> checkDocuments(ID identifier, List<Document>? documents, {ID? sender}) async {
    DateTime? lastTime;
    if (documents != null) {
      lastTime = getLastDocumentTime(identifier, documents);
    }
    if (!needsQueryDocuments(identifier, lastTime)) {
      // no need to update documents now
      return false;
    }
    // send command to ['station@anywhere', sender]
    List<ID> respondents = [Station.ANY];
    if (sender != null) {
      assert(sender != Station.ANY, 'sender error: $sender');
      respondents.add(sender);
    }
    return await queryDocuments(identifier, lastTime, respondents: respondents);
  }

  ///  check whether need to query documents
  // protected
  bool needsQueryDocuments(ID identifier, DateTime? lastTime) {
    if (identifier.isBroadcast) {
      // broadcast entity has no document to query
      return false;
    //} else if (lastTime == null) {
    //  // document time not found, sure to query
    //  return true;
    }
    return _lastDocumentTimes.isExpired(identifier, lastTime);
  }

  // protected
  DateTime? getLastDocumentTime(ID identifier, List<Document> documents) {
    if (documents.isEmpty) {
      return null;
    }
    DateTime? lastTime;
    DateTime? docTime;
    for (Document doc in documents) {
      assert(doc.identifier == identifier, 'document not match: $identifier, $doc');
      docTime = doc.time;
      if (docTime == null) {
        // assert(false, 'document error: $doc');
        logWarning('document time error: $doc');
      } else if (lastTime == null || lastTime.isBefore(docTime)) {
        lastTime = docTime;
      }
    }
    return lastTime;
  }

  //
  //  Group Members
  //

  ///  Check group members for querying
  ///
  /// @param group      - group ID
  /// @param members    - exist members
  /// @param sender     - message sender
  /// @return true on querying
  Future<bool> checkMembers(ID group, List<ID>? members, {ID? sender}) async {
    DateTime? lastTime = await getLastGroupHistoryTime(group);
    if (!needsQueryMembers(group, members, lastTime)) {
      // no need to update group members now
      return false;
    }
    // send command to [sender, lastMember]
    List<ID> respondents = [];
    if (sender != null) {
      assert(sender != Station.ANY, 'sender error: $sender');
      respondents.add(sender);
    }
    ID? lastMember = getLastActiveMember(group: group);
    if (lastMember != null && lastMember != sender) {
      respondents.add(lastMember);
    }
    return await queryMembers(group, lastTime, respondents: respondents);
  }

  ///  check whether need to query group members
  // protected
  bool needsQueryMembers(ID group, List<ID>? members, DateTime? lastTime) {
    if (group.isBroadcast) {
      // broadcast group has no members to query
      return false;
    } else if (members != null && members.isEmpty) {
      // members not found, sure to query
      return true;
    }
    return _lastHistoryTimes.isExpired(group, lastTime);
  }

  Future<DateTime?> getLastGroupHistoryTime(ID group) async {
    var array = await database.getGroupHistories(group: group);
    if (array.isEmpty) {
      return null;
    }
    DateTime? lastTime;
    GroupCommand his;
    DateTime? hisTime;
    for (var pair in array) {
      his = pair.first;
      hisTime = his.time;
      if (hisTime == null) {
        // assert(false, 'group command error: $his');
        logWarning('group command time error: $his');
      } else if (lastTime == null || lastTime.isBefore(hisTime)) {
        lastTime = hisTime;
      }
    }
    return lastTime;
  }

  // -------- Querying

  ///  Request for meta with entity ID
  ///  (call 'isMetaQueryExpired()' before sending command)
  ///
  /// @param identifier  - entity ID
  /// @param respondents - receivers
  /// @return false on duplicated
  Future<bool> queryMeta(ID identifier, {required List<ID> respondents});

  ///  Request for documents with entity ID
  ///  (call 'isDocumentQueryExpired()' before sending command)
  ///
  /// @param identifier  - entity ID
  /// @param lastTime    - last document time
  /// @param respondents - receivers
  /// @return false on duplicated
  Future<bool> queryDocuments(ID identifier, DateTime? lastTime, {required List<ID> respondents});

  ///  Request for group members with group ID
  ///  (call 'isMembersQueryExpired()' before sending command)
  ///
  /// @param group       - group ID
  /// @param lastTime    - last history time
  /// @param respondents - receivers
  /// @return false on duplicated
  Future<bool> queryMembers(ID group, DateTime? lastTime, {required List<ID> respondents});

  // -------- Responding

  ///  Send meta to recipients
  Future<bool> sendMeta(ID identifier, Meta meta, {required List<ID> recipients});

  ///  Send documents to recipients
  ///  if document is updated, force to send it again.
  ///  else only send once every 10 minutes.
  Future<bool> sendDocuments(ID identifier, List<Document> docs, {bool updated = false, required List<ID> recipients});

}
