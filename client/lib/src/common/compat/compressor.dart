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

import 'package:dimsdk/dimsdk.dart';

import 'compatible.dart';


class CompatibleCompressor extends MessageCompressor {
  CompatibleCompressor() : super(CompatibleShortener());

  // @override
  // Uint8List compressContent(Mapping content, Mapping key) {
  //   //CompatibleOutgoing.fixContent(content);
  //   return super.compressContent(content, key);
  // }

  @override
  Mapping? extractContent(Uint8List data, Mapping key) {
    Mapping? content = super.extractContent(data, key);
    if (content != null) {
      CompatibleIncoming.fixContent(content);
    }
    return content;
  }

}


class CompatibleShortener extends MessageShortener {

  @override
  Mapping compressContent(Mapping content) {
    // DON'T COMPRESS NOW
    return content;
  }

  @override
  Mapping compressSymmetricKey(Mapping key) {
    // DON'T COMPRESS NOW
    return key;
  }

  @override
  Mapping compressReliableMessage(Mapping msg) {
    // DON'T COMPRESS NOW
    return msg;
  }

  @override
  Mapping extractReliableMessage(Mapping msg) {
    msg = _fixKey(msg);
    return super.extractReliableMessage(msg);
  }

  // private
  Mapping _fixKey(MutableMapping msg) {
    var keys = msg["K"];
    if (keys == null) {
      // assert(msg["data"] != null, "message data should not empty: $msg");
    } else if (keys is Map) {
      assert(msg["keys"] == null, "message keys duplicated: $msg");
      msg.remove("K");
      msg["keys"] = keys;
    } else if (keys is String) {
      assert(msg["key"] == null, "message key duplicated: $msg");
      msg.remove("K");
      msg["key"] = keys;
    } else {
      assert(false, "message key error: $msg");
    }
    return msg;
  }

}
