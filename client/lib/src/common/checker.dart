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
  final FrequencyChecker<ID> _metaQueries    = FrequencyChecker(QUERY_EXPIRES);
  final FrequencyChecker<ID> _docsQueries    = FrequencyChecker(QUERY_EXPIRES);
  final FrequencyChecker<ID> _membersQueries = FrequencyChecker(QUERY_EXPIRES);

  /// response checker
  final FrequencyChecker<ID> _visaResponses  = FrequencyChecker(RESPOND_EXPIRES);

  /// recent time checkers
  final RecentTimeChecker<ID> _lastDocumentTimes = RecentTimeChecker();
  final RecentTimeChecker<ID> _lastHistoryTimes  = RecentTimeChecker();

  /// group => member
  final Map<ID, ID> _lastActiveMembers = {};

  // protected
  final AccountDBI database;

  EntityChecker(this.database);

  // protected
  bool isMetaQueryExpired(ID identifier)     => _metaQueries.isExpired(identifier);
  bool isDocumentQueryExpired(ID identifier) => _docsQueries.isExpired(identifier);
  bool isMembersQueryExpired(ID identifier)  => _membersQueries.isExpired(identifier);
  bool isDocumentResponseExpired(ID identifier, bool force) =>
      _visaResponses.isExpired(identifier, force: force);

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
  /// @return ture on querying
  Future<bool> checkMeta(ID identifier, Meta? meta) async {
    if (needsQueryMeta(identifier, meta)) {
      // if (!isMetaQueryExpired(identifier)) {
      //   // query not expired yet
      //   return false;
      // }
      return await queryMeta(identifier);
    } else {
      // no need to query meta again
      return false;
    }
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
    assert(MetaUtils.matchIdentifier(identifier, meta), 'meta not match: $identifier, $meta');
    return false;
  }

  //
  //  Documents
  //

  ///  Check documents for querying/updating
  ///
  /// @param identifier - entity ID
  /// @param documents  - exist document
  /// @return true on querying
  Future<bool> checkDocuments(ID identifier, List<Document> documents) async {
    if (needsQueryDocuments(identifier, documents)) {
      // if (!isDocumentQueryExpired(identifier)) {
      //   // query not expired yet
      //   return false;
      // }
      return await queryDocuments(identifier, documents);
    } else {
      // no need to update documents now
      return false;
    }
  }

  ///  check whether need to query documents
  // protected
  bool needsQueryDocuments(ID identifier, List<Document> documents) {
    if (identifier.isBroadcast) {
      // broadcast entity has no document to query
      return false;
    } else if (documents.isEmpty) {
      // documents not found, sure to query
      return true;
    }
    DateTime? current = getLastDocumentTime(identifier, documents);
    return _lastDocumentTimes.isExpired(identifier, current);
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
  /// @param group   - group ID
  /// @param members - exist members
  /// @return true on querying
  Future<bool> checkMembers(ID group, List<ID> members) async {
    if (await needsQueryMembers(group, members)) {
      // if (!isMembersQueryExpired(group)) {
      //   // query not expired yet
      //   return false;
      // }
      return await queryMembers(group, members);
    } else {
      // no need to update group members now
      return false;
    }
  }

  ///  check whether need to query group members
  // protected
  Future<bool> needsQueryMembers(ID group, List<ID> members) async {
    if (group.isBroadcast) {
      // broadcast group has no members to query
      return false;
    } else if (members.isEmpty) {
      // members not found, sure to query
      return true;
    }
    DateTime? current = await getLastGroupHistoryTime(group);
    return _lastHistoryTimes.isExpired(group, current);
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
  /// @param identifier - entity ID
  /// @return false on duplicated
  Future<bool> queryMeta(ID identifier);

  ///  Request for documents with entity ID
  ///  (call 'isDocumentQueryExpired()' before sending command)
  ///
  /// @param identifier - entity ID
  /// @param documents  - exist documents
  /// @return false on duplicated
  Future<bool> queryDocuments(ID identifier, List<Document> documents);

    ///  Request for group members with group ID
    ///  (call 'isMembersQueryExpired()' before sending command)
    ///
    /// @param group      - group ID
    /// @param members    - exist members
    /// @return false on duplicated
  Future<bool> queryMembers(ID group, List<ID> members);

  // -------- Responding

  ///  Send my visa document to contact
  ///  if document is updated, force to send it again.
  ///  else only send once every 10 minutes.
  Future<bool> sendVisa(Visa visa, ID receiver, {bool updated = false});

}
