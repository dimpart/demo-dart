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
import '../dim_common.dart';
import 'anonymous.dart';
import 'group.dart';

///  Client Facebook with Address Name Service
class ClientFacebook extends CommonFacebook {
  ClientFacebook(super.adb);

  Future<String> getName(ID identifier) async {
    // get name from document
    Document? doc = await getDocument(identifier, '*');
    if (doc != null) {
      String? name = doc.name;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    // get name from ID
    return Anonymous.getName(identifier);
  }

  @override
  Future<Group?> createGroup(ID identifier) async {
    Group? grp = await super.createGroup(identifier);
    if (grp != null) {
      EntityDataSource? delegate = grp.dataSource;
      if (delegate == null || delegate == this) {
        // replace group's data source
        grp.dataSource = GroupManager();
      }
    }
    return grp;
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
  ID generateID(Meta meta, int? network, {String? terminal}) {
    return _identifierFactory!.generateID(meta, network, terminal: terminal);
  }

  @override
  ID createID({String? name, required Address address, String? terminal}) {
    return _identifierFactory!.createID(name: name, address: address, terminal: terminal);
  }

  @override
  ID? parseID(String identifier) {
    // try ANS record
    ID? id = ClientFacebook.ans?.identifier(identifier);
    if (id != null) {
      return id;
    }
    // parse by original factory
    return _identifierFactory?.parseID(identifier);
  }

}
