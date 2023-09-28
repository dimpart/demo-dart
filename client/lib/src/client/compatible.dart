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

abstract class Compatible {

  static void fixMetaAttachment(ReliableMessage rMsg) {
    Map? meta = rMsg['meta'];
    if (meta != null) {
      fixMetaVersion(meta);
    }
  }

  static void fixMetaVersion(Map meta) {
    int? version = meta['version'];
    if (version == null) {
      meta['version'] = meta['type'];
    } else if (!meta.containsKey('type')) {
      meta['type'] = version;
    }
  }

  static Command fixCommand(Command content) {
    // 1. fix 'cmd'
    content = fixCmd(content);
    // 2. fix other commands
    if (content is MetaCommand) {
      Map? meta = content['meta'];
      if (meta != null) {
        fixMetaVersion(meta);
      }
    } else if (content is ReceiptCommand) {
      fixReceiptCommand(content);
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
