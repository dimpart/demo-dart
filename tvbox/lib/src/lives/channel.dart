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

import 'stream.dart';
import 'factory.dart';


/// TV Channel
class LiveChannel extends Dictionary {
  LiveChannel(super.dict, {String? name}) {
    // channel name
    if (name != null) {
      setValue('name', name);
    }
  }

  /// Name of channel
  String get name => getValue('name', '');

  /// Count of streams
  int get count => getValue('streams', []).length;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz name="$name" count=$count />';
  }

  @override
  bool get isEmpty => count == 0;

  @override
  bool get isNotEmpty => count > 0;

  /// Stream Sources
  List<LiveStream> get streams =>
      LiveStream.convert(getValue('streams', []));

  set streams(Iterable<LiveStream> sources) =>
      setValue('streams', LiveStream.revert(sources));

  /// Update Sources
  bool addStream(LiveStream stream) {
    var sources = streams;
    for (var src in sources) {
      if (src.url == stream.url) {
        // same source,
        // update info?
        return false;
      }
    }
    sources.add(stream);
    streams = sources;
    return true;
  }

  bool addStreams(Iterable<LiveStream> newStreams) {
    var sources = streams;
    int count = 0;
    bool found;
    for (var item in newStreams) {
      found = false;
      for (var src in sources) {
        if (src.url == item.url) {
          // same source,
          // update info?
          found = true;
          break;
        }
      }
      if (!found) {
        sources.add(item);
        count += 1;
      }
    }
    if (count == 0) {
      // nothing changed
      return false;
    }
    streams = sources;
    return true;
  }

  //
  //  Factory methods
  //

  static LiveChannel? parse(Object? info) {
    if (info == null) {
      return null;
    } else if (info is LiveChannel) {
      return info;
    } else if (info is Dictionary) {
      info = info.toMap();
    }
    if (info is! Map) {
      assert(false, 'channel info error: $info');
      return null;
    }
    var factory = LiveFactory();
    return factory.createChannel(info);
  }

  static List<LiveChannel> convert(Iterable array) {
    List<LiveChannel> channels = [];
    LiveChannel? item;
    for (var info in array) {
      item = parse(info);
      if (item != null) {
        channels.add(item);
      }
    }
    return channels;
  }

  static List<Map> revert(Iterable<LiveChannel> channels) {
    List<Map> array = [];
    for (var item in channels) {
      array.add(item.toMap());
    }
    return array;
  }

}
