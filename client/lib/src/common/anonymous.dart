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

import 'package:dimsdk/dimsdk.dart';
import 'package:dim_plugins/mkm.dart';

class Anonymous {

  static String getName(ID identifier) {
    String? name = identifier.name;
    if (name == null || name.isEmpty) {
      name = _name(identifier.type);
    }
    return '$name (${getNumberString(identifier.address)})';
  }

  static String getNumberString(Address address) {
    int number = getNumber(address);
    String string = '$number'.padLeft(10, '0');
    String a = string.substring(0, 3);
    String b = string.substring(3, 6);
    String c = string.substring(6);
    return "$a-$b-$c";
  }

  static int getNumber(Address address) {
    if (address is BTCAddress) {
      return _btcNumber(address.toString());
    }
    if (address is ETHAddress) {
      return _ethNumber(address.toString());
    }
    // TODO: other chain?
    return 0;
  }
}

// get name for entity type
String _name(int type) {
  switch (type) {
    case EntityType.BOT:
      return 'Bot';
    case EntityType.STATION:
      return 'Station';
    case EntityType.ISP:
      return 'ISP';
    case EntityType.ICP:
      return 'ICP';
  }
  if (EntityType.isUser(type)) {
    return 'User';
  } else if (EntityType.isGroup(type)) {
    return 'Group';
  }
  assert(false, 'should not happen');
  return 'Unknown';
}

int _btcNumber(String address) {
  Uint8List? data = Base58.decode(address);
  assert(data != null, 'BTC address error: $address');
  return data == null ? 0 : _userNumber(data);
}
int _ethNumber(String address) {
  Uint8List? data = Hex.decode(address.substring(2));
  assert(data != null, 'ETH address error: $address');
  return data == null ? 0 : _userNumber(data);
}

int _userNumber(Uint8List cc) {
  int len = cc.length;
  return
    (cc[len-4] & 0xFF) << 24 |
    (cc[len-3] & 0xFF) << 16 |
    (cc[len-2] & 0xFF) << 8 |
    (cc[len-1] & 0xFF);
}
