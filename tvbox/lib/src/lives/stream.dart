/* license: https://mit-license.org
 *
 *  TV-Box: Live Stream
 *
 *                                Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import '../types/dictionary.dart';

import 'factory.dart';


/// M3U8
class LiveStream extends Dictionary {
  LiveStream(super.dict, {Uri? url, String? label}) {
    // M3U8
    if (url != null) {
      setValue('url', url.toString());
    }
    // title
    if (label != null) {
      setValue('label', label);
    }
  }

  /// M3U8
  Uri? get url {
    var m3u8 = getValue('url', null);
    return m3u8 == null ? null : parseUri(m3u8);
  }

  String? get label => getValue('label', null);

  @override
  String toString() {
    Type clazz = runtimeType;
    var m3u8 = getValue('url', null);
    return '<$clazz title="$label" url="$m3u8" />';
  }

  @override
  bool operator ==(Object other) {
    if (other is LiveStream) {
      if (identical(this, other)) {
        // same object
        return true;
      }
      return getValue('url', '') == other.getValue('url', '');
    }
    return false;
  }

  @override
  int get hashCode => getValue('url', '').hashCode;

  @override
  bool get isEmpty => getValue('url', '').isEmpty;

  @override
  bool get isNotEmpty => getValue('url', '').isNotEmpty;

  //
  //  Factory methods
  //

  static LiveStream? parse(Object? info) {
    if (info == null) {
      return null;
    } else if (info is LiveStream) {
      return info;
    } else if (info is Dictionary) {
      info = info.toMap();
    }
    if (info is! Map) {
      assert(false, 'stream info error: $info');
      return null;
    }
    var factory = LiveFactory();
    return factory.createStream(info);
  }

  static List<LiveStream> convert(Iterable array) {
    List<LiveStream> streams = [];
    LiveStream? src;
    for (var info in array) {
      src = parse(info);
      if (src != null) {
        streams.add(src);
      }
    }
    return streams;
  }

  static List<Map> revert(Iterable<LiveStream> streams) {
    List<Map> array = [];
    for (var src in streams) {
      array.add(src.toMap());
    }
    return array;
  }

  //
  //  URL
  //

  static Uri? parseUri(String urlString) {
    try {
      return Uri.parse(urlString);
    } catch (e) {
      return null;
    }
  }

}
