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
import 'package:dimp/dimp.dart';
import 'package:dimsdk/dimsdk.dart';

class AddressNameServer implements AddressNameService {
  AddressNameServer() {
    // constant ANS records
    _caches['all']      = ID.kEveryone;
    _caches['everyone'] = ID.kEveryone;
    _caches['anyone']   = ID.kAnyone;
    _caches['owner']    = ID.kAnyone;
    _caches['founder']  = ID.kFounder;
    // reserved names
    for (String item in AddressNameService.keywords) {
      _reserved[item] = true;
    }
  }

  final Map<String, bool>        _reserved = {};
  final Map<String, ID>            _caches = {};
  final Map<ID, List<String>> _namesTables = {};

  @override
  bool isReserved(String name) => _reserved[name] ?? false;

  @override
  ID? identifier(String name) => _caches[name];

  @override
  List<String> names(ID identifier) {
    List<String>? array = _namesTables[identifier];
    if (array == null) {
      array = [];
      // TODO: update all tables?
      for (String key in _caches.keys) {
        if (_caches[key] == identifier) {
          array.add(key);
        }
      }
      _namesTables[identifier] = array;
    }
    return array;
  }

  // protected
  bool cache(String name, ID? identifier) {
    if (isReserved(name)) {
      // this name is reserved, cannot register
      return false;
    }
    if (identifier == null) {
      _caches.remove(name);
      // TODO: only remove one table?
      _namesTables.clear();
    } else {
      _caches[name] = identifier;
      // names changed, remove the table of names for this ID
      _namesTables.remove(identifier);
    }
    return true;
  }

  ///  Save ANS record
  ///
  /// @param name       - username
  /// @param identifier - user ID; if empty, means delete this name
  /// @return true on success
  Future<bool> save(String name, ID? identifier) async {
    // TODO: save new record into database
    return cache(name, identifier);
  }

  /// remove the keywords temporary before save new records
  Future<int> fix(Map<String, String> records) async {
    // _reserved['apns'] = false;
    _reserved['master'] = false;
    _reserved['monitor'] = false;
    _reserved['archivist'] = false;
    _reserved['announcer'] = false;
    _reserved['assistant'] = false;
    // _reserved['station'] = false;
    int count = 0;
    ID? identifier;
    for (String alias in records.keys) {
      identifier = ID.parse(records[alias]);
      assert(identifier != null, 'record error: $alias => ${records[alias]}');
      if (await save(alias, identifier)) {
        count += 1;
      }
    }
    // _reserved['station'] = true;
    _reserved['assistant'] = true;
    _reserved['announcer'] = true;
    _reserved['archivist'] = true;
    _reserved['monitor'] = true;
    _reserved['master'] = true;
    // _reserved['apns'] = true;
    return count;
  }

}
