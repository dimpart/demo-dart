/* license: https://mit-license.org
 *
 *  Cryptography
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
import 'dart:math';
import 'dart:typed_data';

import 'package:dimp/dimp.dart';

import 'digest.dart';
import 'template.dart';


abstract interface class URLBuilder {

  /// Build upload URL
  /// ~~~~~~~~~~~~~~~~
  /// default hash algorithm: "md5(md5(data) + secret + salt)"
  String buildURL(String api, {
    required String enigma,     // enigma key
    required Uint8List secret,  // enigma value
    required Uint8List data,    // upload data
    Map? extra,
  });

}


class UploadURLBuilder implements URLBuilder {

  //
  //  URL: "https://tfs.dim.chat/{ID}/upload?md5={MD5}&salt={SALT}&enigma={ENIGMA}"
  //

  @override
  String buildURL(String api, {
    required String enigma, required Uint8List secret,
    required Uint8List data,
    Map? extra,
  }) {
    assert(enigma.isNotEmpty && secret.isNotEmpty, 'enigma error: "$enigma" length=${secret.length}');
    assert(api.isNotEmpty && data.isNotEmpty, 'upload params error: $api, data: ${data.length} byte(s)');
    // hash: md5(md5(data) + secret + salt)
    Uint8List salt = _EnigmaHelper.random(16);
    Uint8List temp = _EnigmaHelper.concat(MD5.digest(data), secret, salt);
    Uint8List hash = MD5.digest(temp);
    // replace tags
    api = Template.replace(api, 'MD5', Hex.encode(hash));
    api = Template.replace(api, 'SALT', Hex.encode(salt));
    return _EnigmaHelper.replaceEnigma(api, enigma);
  }

}


abstract class _EnigmaHelper {

  /// Set enigma key into URL
  /// replace the tag 'enigma' with new key
  static String replaceEnigma(String url, String enigma) {
    if (url.contains('{ENIGMA}')) {
      return Template.replace(url, 'ENIGMA', enigma);
    }
    return Template.replaceQueryParam(url, 'enigma', enigma);
  }

  //
  //  Bytes
  //

  static Uint8List concat(Uint8List a, Uint8List b, Uint8List c) =>
      Uint8List.fromList(a + b + c);

  static Uint8List random(int size) {
    Uint8List data = Uint8List(size);
    Random r = Random();
    for (int i = 0; i < size; ++i) {
      data[i] = r.nextInt(256);
    }
    return data;
  }

}
