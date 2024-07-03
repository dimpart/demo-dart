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
import 'stream.dart';
import 'channel.dart';
import 'genre.dart';


// Customizable Creator
class LiveCreator {

  LiveStream createStream(Map? info, {Uri? url, String? label}) {
    return LiveStream(info, url: url, label: label);
  }

  LiveChannel createChannel(Map? info, {String? name}) {
    return LiveChannel(info, name: name);
  }

  LiveGenre createGenre(Map? info, {String? title}) {
    return LiveGenre(info, title: title);
  }

}


// Singleton
class LiveFactory {
  factory LiveFactory() => _instance;
  static final LiveFactory _instance = LiveFactory._internal();
  LiveFactory._internal();

  final Map<Uri, LiveStream> _streams = {};  // URL -> Stream

  LiveCreator creator = LiveCreator();

  void clearCaches() {
    _streams.clear();
  }

  /// create stream with map info
  LiveStream? createStream(Map info) {
    String? urlString = info['url'];
    Uri? url = urlString == null ? null : LiveStream.parseUri(urlString);
    if (url == null) {
      assert(false, 'stream url error: $urlString');
      return null;
    }
    // check cache
    LiveStream? src = _streams[url];
    if (src == null) {
      src = creator.createStream(info, url: null, label: null);
      _streams[url] = src;
    }
    return src;
  }

  /// create stream with url
  LiveStream newStream(Uri url, {required String? label}) {
    // check cache
    LiveStream? src = _streams[url];
    if (src == null) {
      src = creator.createStream(null, url: url, label: label);
      _streams[url] = src;
    }
    return src;
  }

  /// create channel with map info
  LiveChannel? createChannel(Map info) {
    String? name = info['name'];
    if (name == null || name.isEmpty) {
      return null;
    }
    return creator.createChannel(info, name: null);
  }

  /// create channel with name
  LiveChannel newChannel(String name) {
    assert(name.isNotEmpty, 'channel name should not be empty');
    return creator.createChannel(null, name: name);
  }

  LiveGenre? createGenre(Map info) {
    String? title = info['title'];
    if (title == null/* || title.isEmpty*/) {
      return null;
    }
    return creator.createGenre(info, title: null);
  }

  LiveGenre newGenre(String title) {
    // assert(title.isNotEmpty, 'genre title should not b empty');
    return creator.createGenre(null, title: title);
  }

}
