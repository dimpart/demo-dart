/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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
import 'dart:collection';
import 'dart:typed_data';

import 'package:dim_plugins/dim_plugins.dart';
import 'package:lnc/log.dart';


final class MetaUtils {
  MetaUtils._();

  ///  Check whether meta matches with entity ID
  ///  (must call this when received a new meta from network)
  ///
  /// @param identifier - entity ID
  /// @param meta       - entity meta
  /// @return true on matched
  static bool matchIdentifier(ID identifier, Meta meta) {
    assert(meta.isValid, 'meta not valid: $meta');
    // check ID.name
    String? seed = meta.seed;
    String? name = identifier.name;
    if (name == null || name.isEmpty) {
      if (seed != null && seed.isNotEmpty) {
        return false;
      }
    } else if (name != seed) {
      return false;
    }
    // check ID.address
    Address old = identifier.address;
    Address gen = Address.generate(meta, old.network);
    return old == gen;
  }

  ///  Check whether meta matches with public key
  ///
  /// @param pKey - public key
  /// @param meta - entity meta
  /// @return true on matched
  static bool matchPublicKey(VerifyKey pKey, Meta meta) {
    assert(meta.isValid, 'meta not valid: $meta');
    // check whether the public key equals to meta.key
    if (pKey == meta.publicKey) {
      return true;
    }
    // check with seed & fingerprint
    String? seed = meta.seed;
    if (seed == null || seed.isEmpty) {
      // NOTICE: ID with BTC/ETH address has no name, so
      //         just compare the key.data to check matching
      return false;
    }
    Uint8List? fingerprint = meta.fingerprint?.bytes;
    if (fingerprint == null || fingerprint.isEmpty) {
      // fingerprint should not be empty here
      return false;
    }
    // check whether keys equal by verifying signature
    Uint8List data = UTF8.encode(seed);
    return pKey.verify(data, fingerprint);
  }

}


final class DocumentUtils {
  DocumentUtils._();

  static String? getDocumentType(Map document) {
    if (document is Document) {
      document = document.toMap();
    }
    var helper = sharedAccountExtensions.helper;
    return helper?.getDocumentType(document);
  }

  static ID? getDocumentID(Map document) {
    if (document is Document) {
      document = document.toMap();
    }
    var helper = sharedAccountExtensions.helper;
    return helper?.getDocumentID(document);
  }

  static String? getVisaTerminal(Visa document) {
    String? terminal = document.getString('terminal');
    if (terminal == null || terminal.isEmpty) {
      ID? did = getDocumentID(document);
      terminal = did?.terminal;
    }
    return terminal;
  }

  static String? getDocumentName(Document document) {
    var value = document.getProperty('name');
    return Converter.getString(value);
  }

  /// Check whether this time is before old time
  static bool isBefore(DateTime? oldTime, DateTime? thisTime) {
    if (oldTime == null || thisTime == null) {
      return false;
    }
    return thisTime.isBefore(oldTime);
  }

  // /// Check whether this document's time is before old document's time
  // static bool isExpired(Document thisDoc, Document oldDoc) {
  //   return isBefore(oldDoc.time, thisDoc.time);
  // }

  /// Select last document matched the type
  static Document? lastDocument(Iterable<Document> documents, [String? type]) {
    if (type == null || type == '*') {
      type = '';
    }
    bool checkType = type.isNotEmpty;

    Document? last;
    String? docType;
    bool matched;
    for (Document doc in documents) {
      // 1. check type
      if (checkType) {
        docType = getDocumentType(doc);
        matched = docType == null || docType.isEmpty || docType == type;
        if (!matched) {
          // type not matched, skip it
          continue;
        }
      }
      // 2. check time
      if (last != null && isBefore(last.time, doc.time)) {
        // skip old document
        continue;
      }
      // got it
      last = doc;
    }
    return last;
  }

  /// Select last visa document
  static Visa? lastVisa(Iterable<Document> documents, [String? terminal]) {
    terminal ??= '*';
    Visa? last;
    bool matched;
    for (Document doc in documents) {
      // 1. check type
      matched = doc is Visa;
      if (!matched) {
        // type not matched, skip it
        continue;
      }
      // 2. check terminal
      if (terminal != '*' && terminal != getVisaTerminal(doc)) {
        // terminal not matched, skip it
        continue;
      }
      // 3. check time
      if (last != null && isBefore(last.time, doc.time)) {
        // skip old document
        continue;
      }
      // got it
      last = doc;
    }
    return last;
  }

  /// Select last bulletin document
  static Bulletin? lastBulletin(Iterable<Document> documents) {
    Bulletin? last;
    bool matched;
    for (Document doc in documents) {
      // 1. check type
      matched = doc is Bulletin;
      if (!matched) {
        // type not matched, skip it
        continue;
      }
      // 2. check time
      if (last != null && isBefore(last.time, doc.time)) {
        // skip old document
        continue;
      }
      // got it
      last = doc;
    }
    return last;
  }

  /// Sort documents by timestamp descending
  static List<Document> sortDocuments(List<Document> documents) {
    // Sort by time DESC
    documents.sort((a, b) {
      final timeA = a.time ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = b.time ?? DateTime.fromMillisecondsSinceEpoch(0);
      // Descending: b.compareTo(a)
      return timeB.compareTo(timeA);
    });
    return documents;
  }

  /// Remove duplicated/expired item(s)
  static List<Document> trimDocuments(final Iterable<Document> documents) {
    List<Document> array = [];
    // Deduplicate by signature string
    Set<String> signatures = HashSet();
    String? sig;
    for (Document doc in documents) {
      sig = doc.getString('signature');
      if (sig == null || signatures.contains(sig)) {
        Log.warning('skip duplicated document: $sig, $doc');
        continue;
      } else {
        signatures.add(sig);
      }
      // next document
      array.add(doc);
    }
    // TODO: remove expired document(s)
    return array;
  }

}
