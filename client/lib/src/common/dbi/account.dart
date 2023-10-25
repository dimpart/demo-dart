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
import 'package:object_key/object_key.dart';


///  Account DBI
///  ~~~~~~~~~~~
abstract class PrivateKeyDBI {

  static const String kMeta = 'M';
  static const String kVisa = 'V';

  ///  Save private key for user
  ///
  /// @param user - user ID
  /// @param key - private key
  /// @param type - 'M' for matching meta.key; or 'V' for matching visa.key
  /// @param sign - whether use for signature
  /// @param decrypt - whether use for decryption
  /// @return false on error
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
      {int sign = 1, required int decrypt});

  ///  Get private keys for user
  ///
  /// @param user - user ID
  /// @return all keys marked for decryption
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user);

  ///  Get private key for user
  ///
  /// @param user - user ID
  /// @return first key marked for signature
  Future<PrivateKey?> getPrivateKeyForSignature(ID user);

  ///  Get private key for user
  ///
  /// @param user - user ID
  /// @return the private key matched with meta.key
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user);

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
      array.add(key.toMap());
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
    String? data = key.getString("data", null);
    assert(data != null && data.isNotEmpty, 'key data error: $key');
    PrivateKey item;
    for (int index = 0; index < privateKeys.length; ++index) {
      item = privateKeys.elementAt(index);
      if (item.getString('data', null) == data) {
        return index;
      }
    }
    return -1;
  }

}


///  Account DBI
///  ~~~~~~~~~~~
abstract class MetaDBI {

  Future<bool> saveMeta(Meta meta, ID entity);

  Future<Meta?> getMeta(ID entity);

}

///  Account DBI
///  ~~~~~~~~~~~
abstract class DocumentDBI {

  Future<bool> saveDocument(Document doc);

  Future<bool> clearDocuments(ID entity, String type);

  Future<List<Document>> getDocuments(ID entity);

}


///  Account DBI
///  ~~~~~~~~~~~
abstract class UserDBI {

  Future<List<ID>> getLocalUsers();

  Future<bool> saveLocalUsers(List<ID> users);

}


///  Account DBI
///  ~~~~~~~~~~~
abstract class ContactDBI {

  Future<List<ID>> getContacts({required ID user});

  Future<bool> saveContacts(List<ID> contacts, {required ID user});

}

///  Account DBI
///  ~~~~~~~~~~~
abstract class GroupDBI {

  Future<ID?> getFounder({required ID group});

  Future<ID?> getOwner({required ID group});

  //
  //  group members
  //
  Future<List<ID>> getMembers({required ID group});
  Future<bool> saveMembers(List<ID> members, {required ID group});

  //
  //  bots for group
  //
  Future<List<ID>> getAssistants({required ID group});
  Future<bool> saveAssistants(List<ID> bots, {required ID group});

  //
  //  group admins
  //
  Future<List<ID>> getAdministrators({required ID group});
  Future<bool> saveAdministrators(List<ID> members, {required ID group});

}

///  Account DBI
///  ~~~~~~~~~~~
abstract class GroupHistoryDBI {

  /// save group commands:
  ///     invite
  ///     expel (deprecated)
  ///     join
  ///     quit
  ///     reset
  ///     resign
  Future<bool> saveGroupHistory(GroupCommand content, ReliableMessage rMsg, {required ID group});

  /// load group commands:
  ///     invite
  ///     expel (deprecated)
  ///     join
  ///     quit
  ///     reset
  ///     resign
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories({required ID group});

  /// load last 'reset' group command
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({required ID group});

  /// clean group commands for members:
  ///     invite
  ///     expel (deprecated)
  ///     join
  ///     quit
  ///     reset
  Future<bool> clearGroupMemberHistories({required ID group});

  /// clean group commands for administrators:
  ///     resign
  Future<bool> clearGroupAdminHistories({required ID group});

}


///  Account DBI
///  ~~~~~~~~~~~
abstract class AccountDBI implements PrivateKeyDBI, MetaDBI, DocumentDBI,
                                     UserDBI, ContactDBI,
                                     GroupDBI, GroupHistoryDBI {

}
