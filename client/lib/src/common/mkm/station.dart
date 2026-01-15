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

import 'provider.dart';
import 'utils.dart';


///  DIM Server
class Station implements User {
  Station(ID identifier, String? host, int port) {
    assert(identifier.type == EntityType.STATION
        || identifier.type == EntityType.ANY, 'station ID error: $identifier');
    _user = BaseUser(identifier);
    _host = host;
    _port = port;
    _isp = null;
  }

  /// Broadcast
  static ID ANY = Identifier.create(name: 'station', address: Address.ANYWHERE);
  static ID EVERY = Identifier.create(name: 'stations', address: Address.EVERYWHERE);
  // ignore_for_file: non_constant_identifier_names

  // inner user
  late User _user;

  String? _host;
  int _port = 0;

  ID? _isp;

  Station.fromID(ID identifier) : this(identifier, null, 0);
  Station.fromRemote(String host, int port) : this(ANY, host, port);

  @override
  bool operator ==(Object other) {
    if (other is Station) {
      return ServiceProvider.sameStation(other, this);
    }
    return _user == other;
  }

  @override
  int get hashCode {
    if (_host != null) {
      return _host.hashCode + _port * 13;
    }
    return _user.hashCode;
  }

  String get className {
    String name = 'Station';
    assert(() {
      name = runtimeType.toString();
      return true;
    }());
    return name;
  }

  @override
  String toString() {
    String clazz = className;
    int network = identifier.address.network;
    // TODO: check (host:port)
    return '<$clazz id="$identifier" network=$network host="$host" port=$port />';
  }

  /// Reload station info: host & port, SP ID
  Future<void> reload() async {
    Document? doc = await profile;
    if (doc != null) {
      String? host = Converter.getString(doc.getProperty('host'));
      if (host != null) {
        _host = host;
      }
      int? port = Converter.getInt(doc.getProperty('port'));
      if (port != null && port > 0) {
        assert(16 < port && port < 65536, 'station port error: $port');
        _port = port;
      }
      ID? sp = ID.parse(doc.getProperty('provider'));
      if (sp != null) {
        _isp = sp;
      }
    }
  }

  /// Station Document
  Future<Document?> get profile async =>
      DocumentUtils.lastDocument(await documents, '*');

  /// Station IP
  String? get host => _host;

  /// Station Port
  int get port => _port;

  ///  ISP ID, station group
  ID? get provider => _isp;

  @override
  ID get identifier => _user.identifier;

  set identifier(ID sid) {
    User inner = BaseUser(sid);
    inner.dataSource = dataSource;
    _user = inner;
  }

  //-------- Entity

  @override
  int get type => _user.type;

  @override
  UserDataSource? get dataSource {
    var facebook = _user.dataSource;
    if (facebook is UserDataSource) {
      return facebook;
    }
    assert(facebook == null, 'user data source error: $facebook');
    return null;
  }

  @override
  set dataSource(EntityDataSource? facebook) {
    _user.dataSource = facebook;
  }

  @override
  Future<Meta> get meta async => await _user.meta;

  @override
  Future<List<Document>> get documents async => await _user.documents;

  //-------- User

  @override
  Future<List<ID>> get contacts async => await _user.contacts;

  @override
  // TODO: implement terminals
  Future<Set<String>> get terminals async => await _user.terminals;

  @override
  Future<bool> verify(Uint8List data, Uint8List signature) async =>
      await _user.verify(data, signature);

  @override
  Future<EncryptedBundle> encryptBundle(Uint8List plaintext) async =>
      await _user.encryptBundle(plaintext);

  @override
  Future<Uint8List> sign(Uint8List data) async => await _user.sign(data);

  @override
  Future<Uint8List?> decryptBundle(EncryptedBundle ciphertext) async =>
      await _user.decryptBundle(ciphertext);

  @override
  Future<Visa?> signVisa(Visa doc) async => await _user.signVisa(doc);

  @override
  Future<bool> verifyVisa(Visa doc) async => await _user.verifyVisa(doc);

}
