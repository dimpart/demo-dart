/* license: https://mit-license.org
 *
 *  Ming-Ke-Ming : Decentralized User Identity Authentication
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
import 'package:dimsdk/dimsdk.dart';
import 'package:dim_plugins/mkm.dart';

import 'network.dart';


class EntityIDFactory extends IdentifierFactory {

  /// Call it when received 'UIApplicationDidReceiveMemoryWarningNotification',
  /// this will remove 50% of cached objects
  ///
  /// @return number of survivors
  int reduceMemory() {
    int finger = 0;
    finger = Barrack.thanos(identifiers, finger);
    return finger >> 1;
  }

  @override // protected
  ID newID(String identifier, {String? name, required Address address, String? terminal}) {
    /// override for customized ID
    return _EntityID(identifier, name: name, address: address, terminal: terminal);
  }

  @override
  ID? parse(String identifier) {
    // check broadcast IDs
    int size = identifier.length;
    if (size < 4 || size > 64) {
      assert(false, 'ID empty');
      return null;
    } else if (size == 15) {
      // "anyone@anywhere"
      String lower = identifier.toLowerCase();
      if (ID.ANYONE.toString() == lower) {
        return ID.ANYONE;
      }
    } else if (size == 19) {
      // "everyone@everywhere"
      // "stations@everywhere"
      String lower = identifier.toLowerCase();
      if (ID.EVERYONE.toString() == lower) {
        return ID.EVERYONE;
      }
    } else if (size == 13) {
      // "moky@anywhere"
      String lower = identifier.toLowerCase();
      if (ID.FOUNDER.toString() == lower) {
        return ID.FOUNDER;
      }
    }
    return super.parse(identifier);
  }

}


class _EntityID extends Identifier {
  _EntityID(super.string, {super.name, required super.address, super.terminal});

  @override
  int get type {
    String? text = name;
    if (text == null || text.isEmpty) {
      // all ID without 'name' field must be a user
      // e.g.: BTC address
      return EntityType.USER;
    }
    // compatible with MKM 0.9.*
    return NetworkID.getType(address.network);
  }

}
