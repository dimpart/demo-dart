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
final class MessageUtils {
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


final class LoginCommandUtils {
  LoginCommandUtils._();

  static String? getLoginTerminal(LoginCommand content) {
    String? terminal = content.getString('terminal');
    if (terminal == null || terminal.isEmpty) {
      ID did = content.identifier;
      terminal = did.terminal;
    }
    if (terminal == null || terminal.isEmpty) {
      // '*'
      return null;
    }
    return terminal;
  }

  /// Sort records by timestamp descending
  static List<Pair<LoginCommand, ReliableMessage>> sortCommandMessages(List<Pair<LoginCommand, ReliableMessage>> records) {
    // Sort by time DESC
    records.sort((a, b) {
      final timeA = a.first.time ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = b.first.time ?? DateTime.fromMillisecondsSinceEpoch(0);
      // Descending: b.compareTo(a)
      return timeB.compareTo(timeA);
    });
    return records;
  }

  /// Remove duplicated/expired record(s)
  static List<Pair<LoginCommand, ReliableMessage>> trimCommandMessages(final Iterable<Pair<LoginCommand, ReliableMessage>> records) {
    List<Pair<LoginCommand, ReliableMessage>> array = [];
    // Duplicate by serial number
    Set<int> numbers = HashSet();
    int sn;
    Set<String> terminals = HashSet();
    String? device;
    ID? did;
    LoginCommand cmd;
    for (var pair in records) {
      cmd = pair.first;
      did = cmd.identifier;
      // check serial number
      sn = cmd.sn;
      if (numbers.contains(sn)) {
        Log.warning('skip duplicated command message: $did, sn: $sn, $cmd');
        continue;
      } else {
        numbers.add(sn);
      }
      // check terminal (device)
      device = cmd.getString('terminal');
      if (device == null || device.isEmpty) {
        device = '*';
      }
      if (terminals.contains(device)) {
        Log.error('skip duplicated command message: $did, device: $device, $cmd');
        continue;
      } else {
        terminals.add(device);
      }
      // next record
      array.add(pair);
    }
    // TODO: remove expired record(s)
    if (array.length != records.length) {
      Log.info('trim ${array.length}/${records.length} commands(s) for $did, sn: ${numbers.length}');
    }
    return array;
  }

}
