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

import '../mkm/provider.dart';
import '../mkm/station.dart';
import 'network.dart';


class EntityIDFactory extends IdentifierFactory {

  /// Call it when received 'UIApplicationDidReceiveMemoryWarningNotification',
  /// this will remove 50% of cached objects
  ///
  /// @return number of survivors
  int reduceMemory() {
    return sharedAccountExtensions.idCache.reduceMemory();
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
    if (13 <= size && size <= 19) {
      // 13 - moky@anywhere
      // 15 - anyone@anywhere
      // 19 - everyone@everywhere
      // 19 - stations@everywhere
      // 16 - station@anywhere
      // 14 - gsp@everywhere
      String lower = identifier.toLowerCase();
      ID? did = _broadcastIdentifiers[lower];
      if (did != null) {
        return did;
      }
    } else if (size < 4 || 128 < size) {
      assert(false, 'invalid id: $identifier');
      return null;
    }
    // normal ID
    return super.parse(identifier);
  }

}

final _broadcastIdentifiers = {

  'moky@anywhere'       : ID.FOUNDER,
  'anyone@anywhere'     : ID.ANYONE,
  'everyone@everywhere' : ID.EVERYONE,

  'station@anywhere'    : Station.ANY,
  'stations@everywhere' : Station.EVERY,
  'gsp@everywhere'      : ServiceProvider.GSP,

};


class _EntityID extends ConstantString implements ID {
  _EntityID(super.string, {
    String? name, required Address address, String? terminal
  }) : _name = name, _address = address, _terminal = terminal;

  final String? _name;
  final Address _address;
  final String? _terminal;

  @override
  String? get name => _name;

  @override
  Address get address => _address;

  @override
  String? get terminal => _terminal;

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

  @override
  bool get isBroadcast => EntityType.isBroadcast(type);

  @override
  bool get isUser => EntityType.isUser(type);

  @override
  bool get isGroup => EntityType.isGroup(type);

  @override
  bool isSameAs(Object? other) {
    ID? did  = ID.parse(other);
    if (did == null) {
      // should not happen
      return false;
    } else if (identical(did, this)) {
      // same object
      return true;
    }
    //
    //  1. check address
    //
    if (address != did.address) {
      // addresses not equal,
      // sure not the same entity
      return false;
    }
    //
    //  2. check name
    //
    String thisName = name ?? '';
    String thatName = did.name ?? '';
    return thisName == thatName;
  }

  @override
  ID withoutTerminal() {
    // check old terminal (device)
    String? device = terminal;
    if (device == null/* || device.isEmpty*/) {
      // nothing changed
      return this;
    }
    // create new ID without terminal
    return ID.create(name: name, address: address);
  }

  @override
  ID withTerminal(String newTerminal) {
    // check old terminal (device)
    String oldTerminal = terminal ?? '';
    if (newTerminal.isEmpty) {
      // should not happen
      return oldTerminal.isEmpty ? this : ID.create(name: name, address: address);
    }
    // new terminal not empty (normally),
    // try to add/replace terminal
    if (newTerminal == oldTerminal) {
      // old terminal equals to the new terminal,
      // nothing changed
      return this;
    }
    // create new ID with terminal
    return ID.create(name: name, address: address, terminal: newTerminal);
  }

}
