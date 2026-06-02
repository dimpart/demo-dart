/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2026 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2026 Albert Moky
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

import 'package:dim_plugins/crypto.dart';


///
///  Hex encoding
///

class HexData extends BaseData {
  HexData(super.encoded, super.bytes);

  factory HexData.create(String encoded, Uint8List bytes)=>
      HexData(encoded, bytes);

  factory HexData.createWithString(String encoded) =>
      HexData(encoded, null);

  factory HexData.createWithBytes(Uint8List bytes) =>
      HexData('', bytes);

  //
  //  TransportableData
  //

  @override
  String? get encoding => EncodeAlgorithms.HEX;

  @override
  Uint8List? get bytes {
    Uint8List? bin = binary;
    if (bin == null) {
      String txt = string;
      bin = Hex.decode(txt);
      binary = bin;
      assert(bin != null, 'failed to decode hex string: $txt');
    }
    return bin;
  }


  @override
  String toString() {
    String txt = string;
    if (txt == '') {
      Uint8List? bin = binary;
      if (bin != null) {
        txt = Hex.encode(bin);
        string = txt;
      }
      assert(txt.isNotEmpty, 'failed to encode hex data: ${bin?.length} byte(s)');
    }
    return txt;
  }

}
