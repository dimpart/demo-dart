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
import 'dart:convert';
import 'dart:typed_data';

import 'package:dimp/crypto.dart';
import 'package:lnc/log.dart';
import 'package:stargate/startrek.dart';
import 'package:stargate/stargate.dart';


/// Client Gate
class AckEnableGate extends CommonGate {
  AckEnableGate(super.keeper);

  @override
  Porter createPorter({required SocketAddress remote, SocketAddress? local}) {
    var docker = AckEnablePorter(remote: remote, local: local);
    docker.delegate = delegate;
    return docker;
  }

}


class AckEnablePorter extends PlainPorter {
  AckEnablePorter({super.remote, super.local});

  @override
  Future<Arrival?> checkArrival(Arrival income) async {
    if (income is PlainArrival) {
      Uint8List payload = income.payload;
      // check payload
      if (payload.isEmpty) {
        // return null;
      } else if (payload[0] == _jsonBegin) {
        Uint8List? sig = _fetchValue(payload, DataUtils.bytes('signature'));
        Uint8List? sec = _fetchValue(payload, DataUtils.bytes('time'));
        if (sig != null && sec != null) {
          // respond
          String? signature = UTF8.decode(sig);
          String? timestamp = UTF8.decode(sec);
          String text = 'ACK:{"time":$timestamp,"signature":"$signature"}';
          Log.info('sending response: $text');
          await send(DataUtils.bytes(text), DeparturePriority.SLOWER);
        }
      }
    }
    return await super.checkArrival(income);
  }

}

final int _jsonBegin = '{'.codeUnitAt(0);

Uint8List? _fetchValue(Uint8List data, Uint8List tag) {
  if (tag.isEmpty) {
    return null;
  }
  // search tag
  int pos = DataUtils.find(data, sub: tag, start: 0);
  if (pos < 0) {
    return null;
  } else {
    pos += tag.length;
  }
  // skip to start of value
  pos = DataUtils.find(data, sub: DataUtils.bytes(':'), start: pos);
  if (pos < 0) {
    return null;
  } else {
    pos += 1;
  }
  // find end value
  int end = DataUtils.find(data, sub: DataUtils.bytes(','), start: pos);
  if (end < 0) {
    end = DataUtils.find(data, sub: DataUtils.bytes('}'), start: pos);
    if (end < 0) {
      return null;
    }
  }
  Uint8List value = data.sublist(pos, end);
  value = DataUtils.strip(value, removing: DataUtils.bytes(' '));
  value = DataUtils.strip(value, removing: DataUtils.bytes('"'));
  value = DataUtils.strip(value, removing: DataUtils.bytes("'"));
  return value;
}


abstract interface class DataUtils {

  static Uint8List bytes(String text) =>
      Uint8List.fromList(utf8.encode(text));

  static int find(Uint8List data, {required Uint8List sub, int start = 0}) {
    int end = data.length - sub.length;
    int i, j;
    bool match;
    for (i = start; i <= end; ++i) {
      match = true;
      for (j = 0; j < sub.length; ++j) {
        if (data[i + j] == sub[j]) {
          continue;
        }
        match = false;
        break;
      }
      if (match) {
        return i;
      }
    }
    return -1;
  }

  static Uint8List strip(Uint8List data, {required removing}) =>
      stripLeft(
        stripRight(data, trailing: removing),
        leading: removing,
      );

  static Uint8List stripLeft(Uint8List data, {required Uint8List leading}) {
    if (leading.isEmpty) {
      return data;
    }
    int i;
    while (true) {
      if (data.length < leading.length) {
        return data;
      }
      for (i = 0; i < leading.length; ++i) {
        if (data[i] != leading[i]) {
          // not match
          return data;
        }
      }
      // matched, remove the leading bytes
      data = data.sublist(leading.length);
    }
  }

  static Uint8List stripRight(Uint8List data, {required Uint8List trailing}) {
    if (trailing.isEmpty) {
      return data;
    }
    int i, m;
    while (true) {
      m = data.length - trailing.length;
      if (m < 0) {
        return data;
      }
      for (i = 0; i < trailing.length; ++i) {
        if (data[m + i] != trailing[i]) {
          // not match
          return data;
        }
      }
      // matched, remove the tailing bytes
      data = data.sublist(0, m);
    }
  }

}
