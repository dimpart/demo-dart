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
import 'dart:typed_data';

import 'package:dimp/dimp.dart';
import 'package:lnc/log.dart';
import 'package:startrek/startrek.dart';


class MessageQueue with Logging {

  final List<int> _priorities = [];
  final Map<int, List<MessageWrapper>> _fleets = {};

  ///  Append message with departure ship
  ///
  /// @param rMsg - outgoing message
  /// @param ship - departure ship
  /// @return false on duplicated
  bool append(ReliableMessage rMsg, Departure ship) {
    bool ok = true;
    // 1. choose an array with priority
    int priority = ship.priority;
    List<MessageWrapper>? array = _fleets[priority];
    if (array == null) {
      // 1.1. create new array for this priority
      array = [];
      _fleets[priority] = array;
      // 1.2. insert the priority in a sorted list
      _insert(priority);
    } else {
      // 1.3. check duplicated
      var signature = rMsg['signature'];
      assert(signature != null, 'signature not found: $rMsg');
      ReliableMessage? item;
      for (MessageWrapper wrapper in array) {
        item = wrapper.message;
        if (item != null && _isDuplicated(item, rMsg)) {
          logWarning('[QUEUE] duplicated message: $signature');
          ok = false;
          break;
        }
      }
    }
    if (ok) {
      // 2. append with wrapper
      MessageWrapper wrapper = MessageWrapper(rMsg, ship);
      array.add(wrapper);
    }
    return ok;
  }
  bool _isDuplicated(ReliableMessage msg1, ReliableMessage msg2) {
    var sig1 = msg1['signature'];
    var sig2 = msg2['signature'];
    if (sig1 == null || sig2 == null) {
      assert(false, 'signature should not empty here: $msg1, $msg2');
      return false;
    } else if (sig1 != sig2) {
      return false;
    }
    // maybe it's a group message split for every members,
    // so we still need to check receiver here.
    ID to1 = msg1.receiver;
    ID to2 = msg2.receiver;
    return to1 == to2;
  }
  void _insert(int priority) {
    int total = _priorities.length;
    int index = 0, value;
    // seeking position for new priority
    for (; index < total; ++index) {
      value = _priorities[index];
      if (value == priority) {
        // duplicated
        return;
      } else if (value > priority) {
        // got it
        break;
      }
      // current value is smaller than the new value,
      // keep going
    }
    // insert new value before the bigger one
    _priorities.insert(index, priority);
  }

  ///  Get next new message
  ///
  /// @return MessageWrapper
  MessageWrapper? next() {
    for (int priority in _priorities) {
      // get first task
      List<MessageWrapper>? array = _fleets[priority];
      if (array != null && array.isNotEmpty) {
        return array.removeAt(0);
      }
    }
    return null;
  }

  void purge() {
    _priorities.removeWhere((prior) {
      List<MessageWrapper>? array = _fleets[prior];
      if (array == null) {
        // this priority is empty
        return true;
      } else if (array.isEmpty) {
        // this priority is empty
        _fleets.remove(prior);
        return true;
      }
      return false;
    });
  }
}


class MessageWrapper implements Departure {
  MessageWrapper(ReliableMessage msg, Departure departure)
      : message = msg, _ship = departure;

  ReliableMessage? message;
  final Departure _ship;

  @override
  dynamic get sn => _ship.sn;

  @override
  int get priority => _ship.priority;

  @override
  List<Uint8List> get fragments => _ship.fragments;

  @override
  bool checkResponse(Arrival response) => _ship.checkResponse(response);

  @override
  bool get isImportant => _ship.isImportant;

  @override
  void touch(DateTime now) => _ship.touch(now);

  @override
  ShipStatus getStatus(DateTime now) => _ship.getStatus(now);

}
