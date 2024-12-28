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

import '../protocol/version.dart';


// TODO: remove after all server/client upgraded
abstract interface class Compatible {

  static void fixMetaAttachment(ReliableMessage rMsg) {
    Map? meta = rMsg['meta'];
    if (meta != null) {
      fixMetaVersion(meta);
    }
  }

  static void fixMetaVersion(Map meta) {
    dynamic type = meta['type'];
    if (type == null) {
      type = meta['version'];
    } else if (type is String && !meta.containsKey('algorithm')) {
      // TODO: check number
      if (type.length > 2) {
        meta['algorithm'] = type;
      }
    }
    int version = MetaType.parseInt(type, 0);
    if (version > 0) {
      meta['type'] = version;
      meta['version'] = version;
    }
  }

  static FileContent fixFileContent(FileContent content) {
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
    return content;
  }

  static Command fixCommand(Command content) {
    // 1. fix 'cmd'
    content = fixCmd(content);
    // 2. fix other commands
    if (content is ReceiptCommand) {
      fixReceiptCommand(content);
    } else if (content is MetaCommand) {
      Map? meta = content['meta'];
      if (meta != null) {
        fixMetaVersion(meta);
      }
    }
    // OK
    return content;
  }

  static Command fixCmd(Command content) {
    String? cmd = content['cmd'];
    if (cmd == null) {
      cmd = content['command'];
      content['cmd'] = cmd;
    } else if (!content.containsKey('command')) {
      content['command'] = cmd;
      content = Command.parse(content.toMap())!;
    }
    return content;
  }

  static void fixReceiptCommand(ReceiptCommand content) {
    // TODO: check for v2.0
  }

}
