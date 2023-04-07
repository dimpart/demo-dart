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


///  Account DBI
///  ~~~~~~~~~~~
abstract class PrivateKeyDBI {

  static final String kMeta = 'M';
  static final String kVisa = 'V';

  ///  Save private key for user
  ///
  /// @param user - user ID
  /// @param key - private key
  /// @param type - 'M' for matching meta.key; or 'P' for matching profile.key
  /// @return false on error
  bool savePrivateKey(PrivateKey key, String type, ID user);

  ///  Get private keys for user
  ///
  /// @param user - user ID
  /// @return all keys marked for decryption
  List<DecryptKey> getPrivateKeysForDecryption(ID user);

  ///  Get private key for user
  ///
  /// @param user - user ID
  /// @return first key marked for signature
  PrivateKey? getPrivateKeyForSignature(ID user);

  ///  Get private key for user
  ///
  /// @param user - user ID
  /// @return the private key matched with meta.key
  PrivateKey? getPrivateKeyForVisaSignature(ID user);

  //
  //  Conveniences
  //

  static List<DecryptKey> convertDecryptKeys(List<PrivateKey> privateKeys) {
    List<DecryptKey> decryptKeys = [];
    for (PrivateKey key in privateKeys) {
      if (key is DecryptKey) {
        decryptKeys.add(key as DecryptKey);
      }
    }
    return decryptKeys;
  }
  static List<PrivateKey> convertPrivateKeys(List<DecryptKey> decryptKeys) {
    List<PrivateKey> privateKeys = [];
    for (DecryptKey key in decryptKeys) {
      if (key is PrivateKey) {
        privateKeys.add(key as PrivateKey);
      }
    }
    return privateKeys;
  }

  static List<Map> revertPrivateKeys(List<PrivateKey> privateKeys) {
    List<Map> array = [];
    for (PrivateKey key in privateKeys) {
      array.add(key.dictionary);
    }
    return array;
  }

  static List<PrivateKey>? insertKey(PrivateKey key, List<PrivateKey> privateKeys) {
    int index = findKey(key, privateKeys);
    if (index == 0) {
      // nothing change
      return null;
    } else if (index > 0) {
      // move to the front
      privateKeys.removeAt(index);
    } else if (privateKeys.length > 2) {
      // keep only last three records
      privateKeys.removeAt(privateKeys.length - 1);
    }
    privateKeys.insert(0, key);
    return privateKeys;
  }
  static int findKey(PrivateKey key, List<PrivateKey> privateKeys) {
    String? data = key.getString("data");
    assert(data != null && data.isNotEmpty, 'key data error: $key');
    PrivateKey item;
    for (int index = 0; index < privateKeys.length; ++index) {
      item = privateKeys.elementAt(index);
      if (item.getString('data') == data) {
        return index;
      }
    }
    return -1;
  }

}


///  Account DBI
///  ~~~~~~~~~~~
abstract class MetaDBI {

  bool saveMeta(Meta meta, ID entity);

  Meta? getMeta(ID entity);

}

///  Account DBI
///  ~~~~~~~~~~~
abstract class DocumentDBI {

  bool saveDocument(Document doc);

  Document? getDocument(ID entity, String? type);

}


///  Account DBI
///  ~~~~~~~~~~~
abstract class UserDBI {

  List<ID> getLocalUsers();

  bool saveLocalUsers(List<ID> users);

  List<ID> getContacts(ID user);

  bool saveContacts(List<ID> contacts, ID user);

}

///  Account DBI
///  ~~~~~~~~~~~
abstract class GroupDBI {

  ID? getFounder(ID group);

  ID? getOwner(ID group);

  //
  //  group members
  //
  List<ID> getMembers(ID group);
  bool saveMembers(List<ID> members, ID group);

  //
  //  bots for group
  //
  List<ID> getAssistants(ID group);
  bool saveAssistants(List<ID> bots, ID group);

}


///  Account DBI
///  ~~~~~~~~~~~
abstract class AccountDBI implements PrivateKeyDBI, MetaDBI, DocumentDBI, UserDBI, GroupDBI {

}
