/* license: https://mit-license.org
 *
 *  DIMP : Decentralized Instant Messaging Protocol
 *
 *                                Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * ==============================================================================
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
 * ==============================================================================
 */
import 'dart:collection';

import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';

import '../protocol/login.dart';


/// 1. [Meta Protocol]
/// 2. [Visa Protocol]
class MessageUtils {
  MessageUtils._();

  ///  Sender's Meta
  ///  ~~~~~~~~~~~~~
  ///  Extends for the first message package of 'Handshake' protocol.

  static Meta? getMeta(Message msg) =>
      Meta.parse(msg['meta']);

  static void setMeta(Meta? meta, Message msg) =>
      msg.setMap('meta', meta);

  ///  Sender's Visa
  ///  ~~~~~~~~~~~~~
  ///  Extends for the first message package of 'Handshake' protocol.

  static Visa? getVisa(Message msg) {
    Document? doc = Document.parse(msg['visa']);
    if (doc is Visa) {
      return doc;
    }
    assert(doc == null, 'visa document error: $doc');
    return null;
  }

  static void setVisa(Visa? visa, Message msg) =>
      msg.setMap('visa', visa);

}


class CommandMessageUtils {
  CommandMessageUtils._();

  static String? getLoginTerminal(LoginCommand content) {
    String? terminal = content.getString('terminal');
    if (terminal == null || terminal.isEmpty) {
      terminal = content.getString('device');
      if (terminal == null || terminal.isEmpty) {
        ID did = content.identifier;
        terminal = did.terminal;
      }
    }
    if (terminal == null || terminal.isEmpty) {
      // '*'
      return null;
    }
    return terminal;
  }

  /// Serialize command messages
  static Map dumpCommandMessages(List<Pair<Command, ReliableMessage>> records) {
    // sort and remove duplicated item
    var results = sortCommandMessages(records);
    Log.info('Dump ${results.length}/${records.length} command message(s)');
    return {
      'records': results.map((pair) => {
        'cmd': pair.first.toMap(),
        'msg': pair.second.toMap()
      })
    };
  }

  /// Deserialize command messages
  static List<Pair<Command, ReliableMessage>>? pumpCommandMessages(dynamic info) {
    List? array = fetchCommandMessages(info);
    if (array == null) {
      return null;
    }
    List<Pair<Command, ReliableMessage>> records = [];
    Command? cmd;
    ReliableMessage? msg;
    // Convert each raw map to command + message
    for (var item in array) {
      if (item is Map) {
        cmd = Command.parse(item['cmd']);
        msg = ReliableMessage.parse(item['msg']);
        if (cmd != null && msg != null) {
          records.add(Pair(cmd, msg));
          continue;
        }
      }
      Log.error('command message error: $item');
    }
    // Sort and remove deduplicate item
    var results = sortCommandMessages(records);
    Log.info('Pump ${results.length}/${array.length} command message(s)');
    return results;
  }

}


List? fetchCommandMessages(dynamic info) {
  if (info is List) {
    return info;
  } else if (info is Map) {
    var records = info['records'];
    if (records is List) {
      return records;
    } else if (info.containsKey('cmd') && info.containsKey('msg')) {
      return [info];
    }
  }
  // error
  Log.error('command messages error: $info');
  return null;
}


List<Pair<Command, ReliableMessage>> sortCommandMessages(List<Pair<Command, ReliableMessage>> records) {
  // 1. Sort by time DESC
  final sortedRecords = List.of(records)..sort((a, b) {
    final timeA = a.first.time ?? DateTime.fromMillisecondsSinceEpoch(0);
    final timeB = b.first.time ?? DateTime.fromMillisecondsSinceEpoch(0);
    // Descending: b.compareTo(a)
    return timeB.compareTo(timeA);
  });
  // 2. Duplicate by serial number
  Set<int> numbers = HashSet();
  int sn;
  List<Pair<Command, ReliableMessage>> array = [];
  for (var pair in sortedRecords) {
    sn = pair.first.sn;
    if (numbers.contains(sn)) {
      Log.warning('skip duplicated command message: $sn, ${pair.first}');
      continue;
    } else {
      numbers.add(sn);
    }
    // next record
    array.add(pair);
  }
  // done
  return array;
}
