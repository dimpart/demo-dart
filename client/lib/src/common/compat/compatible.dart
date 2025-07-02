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
import 'package:dimsdk/dimsdk.dart';

import '../protocol/login.dart';
import '../protocol/version.dart';


// TODO: remove after all server/client upgraded
abstract interface class Compatible {

  /// Fix meta
  static void fixMetaAttachment(ReliableMessage rMsg) {
    Map? meta = rMsg['meta'];
    if (meta != null) {
      fixMetaVersion(meta);
    }
  }
  static void fixMetaType(Map meta) => fixMetaVersion(meta);

  /// Fix visa document
  static void fixVisaAttachment(ReliableMessage rMsg) {
    Map? visa = rMsg['visa'];
    if (visa != null) {
      fixDocId(visa);
    }
  }
  static void fixDocumentID(Map document) => fixDocId(document);

}


/// 'cmd' <-> 'command'
void fixCmd(Map content) {
  String? cmd = content['command'];
  if (cmd == null) {
    // 'command' not exists, copy the value from 'cmd'
    cmd = content['cmd'];
    if (cmd != null) {
      content['command'] = cmd;
    } else {
      assert(false, 'command error: $content');
    }
  } else if (content.containsKey('cmd')) {
    // these two values must be equal
    assert(content['cmd'] == cmd, 'command error: $content');
  } else {
    // copy value from 'command' to 'cmd'
    content['cmd'] = cmd;
  }
}

/// 'ID' <-> 'did'
void fixDid(Map content) {
  String? did = content['did'];
  if (did == null) {
    // 'did' not exists, copy the value from 'ID'
    did = content['ID'];
    if (did != null) {
      content['did'] = did;
    // } else {
    //   assert(false, 'did not exists: $content');
    }
  } else if (content.containsKey('ID')) {
    // these two values must be equal
    assert(content['ID'] == did, 'did error: $content');
  } else {
    // copy value from 'did' to 'ID'
    content['ID'] = did;
  }
}

/// 'ID' <-> 'did'
Map fixDocId(Map document) {
  fixDid(document);
  return document;
}

void fixMetaVersion(Map meta) {
  dynamic type = meta['type'];
  if (type == null) {
    type = meta['version'];
  } else if (type is String && !meta.containsKey('algorithm')) {
    // TODO: check number
    if (type.length > 2) {
      meta['algorithm'] = type;
    }
  }
  int version = MetaVersion.parseInt(type, 0);
  if (version > 0) {
    meta['type'] = version;
    meta['version'] = version;
  }
}


void fixFileContent(Map content) {
  var pwd = content['key'];
  if (pwd != null) {
    // Tarsier version > 1.3.7
    // DIM SDK version > 1.1.0
    content['password'] = pwd;
  } else {
    // Tarsier version <= 1.3.7
    // DIM SDK version <= 1.1.0
    pwd = content['password'];
    if (pwd != null) {
      content['key'] = pwd;
    }
  }
}

const fileTypes = [
  ContentType.FILE, 'file',
  ContentType.IMAGE, 'image',
  ContentType.AUDIO, 'audio',
  ContentType.VIDEO, 'video',
];

// TODO: remove after all server/client upgraded
abstract interface class CompatibleIncoming {

  static void fixContent(Map content) {
    // get content type
    String type = Converter.getString(content['type'], null) ?? '';

    if (fileTypes.contains(type)) {
      // 1. 'key' <-> 'password'
      fixFileContent(content);
      return;
    }

    if (ContentType.NAME_CARD == type || type == 'card') {
      // 1. 'ID' <-> 'did'
      fixDid(content);
      return;
    }

    if (ContentType.COMMAND == type || type == 'command') {
      // 1. 'cmd' <-> 'command'
      fixCmd(content);
    }
    //
    //  get command name
    //
    String? cmd = content['command'];
    // cmd = Converter.getString(cmd, null);
    if (cmd == null || cmd.isEmpty) {
      return;
    }

    // if (Command.RECEIPT == cmd) {
    //   // pass
    // }

    if (LoginCommand.LOGIN == cmd) {
      // 2. 'ID' <-> 'did'
      fixDid(content);
      return;
    }

    if (Command.DOCUMENTS == cmd || cmd == 'document') {
      // 2. cmd: 'document' -> 'documents'
      _fixDocs(content);
    }

    if (Command.META == cmd || Command.DOCUMENTS == cmd || cmd == 'document') {
      // 3. 'ID' <-> 'did'
      Map? meta = content['meta'];
      if (meta != null) {
        // 4. 'type' <-> 'version'
        fixMetaVersion(meta);
      }
    }

  }

  static void _fixDocs(Map content) {
    // cmd: 'document' -> 'documents'
    String? cmd = content['command'];
    if (cmd == 'document') {
      content['command'] = 'documents';
    }
    // 'document' -> 'documents
    Map? doc = content['document'];
    if (doc != null) {
      content['documents'] = [fixDocId(doc)];
      content.remove('document');
    }
  }

}


/// change 'type' value from string to int
void fixType(Map content) {
  var type = content['type'];
  if (type is String) {
    int? number = Converter.getInt(type, -1);
    if (number != null && number >= 0) {
      content['type'] = number;
    }
  }
}

/// TODO: remove after all server/client upgraded
abstract interface class CompatibleOutgoing {

  static void fixContent(Content content) {
    // fix content type
    fixType(content.toMap());

    if (content is FileContent) {
      // 1. 'key' <-> 'password'
      fixFileContent(content.toMap());
      return;
    }

    if (content is NameCard) {
      // 1. 'ID' <-> 'did'
      fixDid(content.toMap());
      return;
    }

    if (content is Command) {
      // 1. 'cmd' <-> 'command'
      fixCmd(content.toMap());
    }

    if (content is ReceiptCommand) {
      // 2. check for v2.0
      fixReceiptCommand(content);
      return;
    }

    if (content is LoginCommand) {
      // 2. 'ID' <-> 'did'
      fixDid(content.toMap());
      // 3. fix station
      var station = content['station'];
      if (station is Map) {
        fixDid(station);
      }
      // 4. fix provider
      var provider = content['provider'];
      if (provider is Map) {
        fixDid(provider);
      }
      return;
    }

    // if (content is ReportCommand) {
    //   // check state for oldest version
    // }

    if (content is DocumentCommand) {
      // 2. cmd: 'documents' -> 'document'
      _fixDocs(content);
    }

    if (content is MetaCommand) {
      // 3. 'ID' <-> 'did'
      fixDid(content.toMap());
      Map? meta = content['meta'];
      if (meta != null) {
        // 4. 'type' <-> 'version'
        fixMetaVersion(meta);
      }
    }

  }

  static void _fixDocs(DocumentCommand content) {
    // cmd: 'documents' -> 'document'
    String cmd = content.cmd;
    if (cmd == 'documents') {
      content['cmd'] = 'document';
      content['command'] = 'document';
    }
    // 'documents' -> 'document'
    List? array = content['documents'];
    if (array != null) {
      List<Document> docs = Document.convert(array);
      Document? last = DocumentUtils.lastDocument(docs);
      if (last != null) {
        content['document'] = fixDocId(last.toMap());
      }
      if (docs.length == 1) {
        content.remove('documents');
      }
    }
    Map? document = content['document'];
    if (document != null) {
      fixDocId(document);
    }
  }

}

void fixReceiptCommand(ReceiptCommand content) {
  // TODO: check for v2.0
}
