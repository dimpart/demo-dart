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
import 'package:dim_plugins/dim_plugins.dart';
import 'package:dimp/dimp.dart';

import 'btc.dart';
import 'network.dart';

class _EntityID extends Identifier {
  _EntityID(super.string,
      {String? name, required Address address, String? terminal})
      : super(name: name, address: address, terminal: terminal);

  // compatible with MKM 0.9.*
  @override
  int get type => NetworkID.getType(address.type);
}

class _EntityIDFactory extends IdentifierFactory {

  @override // protected
  ID newID(String identifier, {String? name, required Address address, String? terminal}) {
    /// override for customized ID
    return _EntityID(identifier, name: name, address: address, terminal: terminal);
  }

  @override
  ID? parse(String identifier) {
    assert(identifier.isNotEmpty, 'ID empty');
    int len = identifier.length;
    if (len == 15) {
      // "anyone@anywhere"
      String lower = identifier.toLowerCase();
      if (ID.kAnyone.toString() == lower) {
        return ID.kAnyone;
      }
    } else if (len == 19) {
      // "everyone@everywhere"
      // "stations@everywhere"
      String lower = identifier.toLowerCase();
      if (ID.kEveryone.toString() == lower) {
        return ID.kEveryone;
      }
    } else if (len == 13) {
      // "moky@anywhere"
      String lower = identifier.toLowerCase();
      if (ID.kFounder.toString() == lower) {
        return ID.kFounder;
      }
    }
    return super.parse(identifier);
  }
}

class _CompatibleAddressFactory extends BaseAddressFactory {

  @override
  Address? createAddress(String address) {
    assert(address.isNotEmpty, 'address empty');
    int len = address.length;
    if (len == 8) {
      // "anywhere"
      String lower = address.toLowerCase();
      if (lower == Address.kAnywhere.toString()) {
        return Address.kAnywhere;
      }
    } else if (len == 10) {
      // "everywhere"
      String lower = address.toLowerCase();
      if (lower == Address.kEverywhere.toString()) {
        return Address.kEverywhere;
      }
    }
    Address? res;
    if (len == 42) {
      res = ETHAddress.parse(address);
    } else if (26 <= len && len <= 35) {
      res = CompatibleBTCAddress.parse(address);
    }
    assert(res != null, 'invalid address: $address');
    return res;
  }

}

void registerEntityIDFactory() {
  ID.setFactory(_EntityIDFactory());
}

void registerCompatibleAddressFactory() {
  Address.setFactory(_CompatibleAddressFactory());
}
