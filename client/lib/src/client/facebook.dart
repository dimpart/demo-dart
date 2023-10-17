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

import '../common/ans.dart';
import '../common/facebook.dart';
import '../common/register.dart';

///  Client Facebook with Address Name Service
class ClientFacebook extends CommonFacebook {
  ClientFacebook(super.adb);

  @override
  Future<bool> saveDocument(Document doc) async {
    bool ok = await super.saveDocument(doc);
    if (ok && doc is Bulletin) {
      ID group = doc.identifier;
      assert(group.isGroup, 'group ID error: $group');
      List<ID>? admins = _getAdministratorsFromBulletin(doc);
      if (admins != null) {
        ok = await saveAdministrators(admins, group);
      }
    }
    return ok;
  }

  List<ID>? _getAdministratorsFromBulletin(Bulletin doc) {
    Object? administrators = doc.getProperty('administrators');
    if (administrators is List) {
      return ID.convert(administrators);
    }
    // admins not found
    return null;
  }

  Future<bool> saveMembers(List<ID> members, ID group) async =>
      await database.saveMembers(members, group: group);

  Future<bool> saveAssistants(List<ID> bots, ID group) async =>
      await database.saveAssistants(bots, group: group);

  Future<bool> saveAdministrators(List<ID> admins, ID group) async =>
      await database.saveAdministrators(admins, group: group);

  Future<List<ID>> getAdministrators(ID group) async {
    List<ID> admins = await database.getAdministrators(group: group);
    if (admins.isNotEmpty) {
      // got from database
      return admins;
    }
    Document? doc = await getDocument(group, '*');
    if (doc is Bulletin) {
      // try to get from bulletin document
      admins = _getAdministratorsFromBulletin(doc) ?? [];
    }
    return admins;
  }

  //
  //  Address Name Service
  //
  static AddressNameServer? ans;

  static void prepare() {
    if (_loaded) {
      return;
    }

    // load plugins
    Register.prepare();

    _identifierFactory = ID.getFactory();
    ID.setFactory(_IdentifierFactory());

    _loaded = true;
  }
  static bool _loaded = false;
}

IDFactory? _identifierFactory;

class _IdentifierFactory implements IDFactory {

  @override
  ID generateIdentifier(Meta meta, int? network, {String? terminal}) {
    return _identifierFactory!.generateIdentifier(meta, network, terminal: terminal);
  }

  @override
  ID createIdentifier({String? name, required Address address, String? terminal}) {
    return _identifierFactory!.createIdentifier(name: name, address: address, terminal: terminal);
  }

  @override
  ID? parseIdentifier(String identifier) {
    // try ANS record
    ID? id = ClientFacebook.ans?.identifier(identifier);
    if (id != null) {
      return id;
    }
    // parse by original factory
    return _identifierFactory?.parseIdentifier(identifier);
  }

}
