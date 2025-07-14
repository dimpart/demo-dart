/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'package:dimsdk/core.dart';

import 'compatible.dart';


class CompatibleCompressor extends MessageCompressor {
  CompatibleCompressor() : super(CompatibleShortener());

  // @override
  // Uint8List compressContent(Map content, Map key) {
  //   //CompatibleOutgoing.fixContent(content);
  //   return super.compressContent(content, key);
  // }

  @override
  Map? extractContent(Uint8List data, Map key) {
    Map? content = super.extractContent(data, key);
    if (content != null) {
      CompatibleIncoming.fixContent(content);
    }
    return content;
  }

}


class CompatibleShortener extends MessageShortener {

  @override  // protected
  void moveKey(String from, String to, Map info) {
    var value = info[from];
    if (value != null) {
      if (info[to] != null) {
        assert(false, 'keys conflicted: "$from" -> "$to", $info');
        return;
      }
      info.remove(from);
      info[to] = value;
    }
  }

  @override
  Map compressContent(Map content) {
    // DON'T COMPRESS NOW
    return content;
  }

  @override
  Map compressSymmetricKey(Map key) {
    // DON'T COMPRESS NOW
    return key;
  }

  @override
  Map compressReliableMessage(Map msg) {
    // DON'T COMPRESS NOW
    return msg;
  }

}
