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
import '../types/tuple.dart';

import 'stream.dart';
import 'channel.dart';
import 'genre.dart';
import 'factory.dart';


class LiveParser {
  LiveParser();

  final LiveFactory factory = LiveFactory();

  List<LiveGenre> parse(String text) => parseLines(text.split('\n'));

  // protected
  List<LiveGenre> parseLines(List<String> lines) {
    List<LiveGenre> allGroups = [];
    LiveGenre current = factory.newGenre('Default');
    for (String item in lines) {
      String text = item.trim();
      if (text.isEmpty) {
        continue;
      } else if (text.startsWith(r'#')) {
        continue;
      } else if (text.startsWith(r'//')) {
        continue;
      }
      //
      //  1. check genre
      //
      var genre = fetchGenre(text);
      if (genre != null) {
        // alternate current group
        if (current.isNotEmpty) {
          allGroups.add(current);
        }
        // create next group
        current = genre;
        continue;
      }
      //
      //  2. check channel
      //
      var pair = fetchChannel(text);
      var channel = pair.first;
      if (channel == null) {
        // empty line?
        continue;
      }
      // split streams
      var sources = pair.second.split(r'#');
      //
      //  3. create streams
      //
      Set<LiveStream> streams = {};
      for (var src in sources) {
        var m3u8 = fetchStream(src);
        if (m3u8 != null) {
          streams.add(m3u8);
        }
      }
      channel.addStreams(streams);
      current.addChannel(channel);
    }
    // add last group
    if (current.isNotEmpty) {
      allGroups.add(current);
    }
    return allGroups;
  }

  //
  //  Creators (protected)
  //

  /// get group title
  LiveGenre? fetchGenre(String text) {
    String? title = splitGenre(text);
    if (title == null) {
      return null;
    }
    return factory.newGenre(title);
  }

  /// get channel name & stream sources
  Pair<LiveChannel?, String> fetchChannel(String text) {
    Pair<String?, String> pair = splitChannel(text);
    String? name = pair.first;
    if (name == null) {
      return Pair(null, text);
    }
    LiveChannel channel = factory.newChannel(name);
    return Pair(channel, pair.second);
  }

  /// split stream sources with '#'
  LiveStream? fetchStream(String text) {
    Pair<Uri?, String?> pair = splitStream(text);
    Uri? url = pair.first;
    if (url == null) {
      return null;
    }
    return factory.newStream(url, label: pair.second);
  }

  //
  //  Split Utils
  //

  static String? splitGenre(String text) {
    int pos = text.indexOf(r',#genre#');
    if (pos < 0) {
      return null;
    }
    String title = text.substring(0, pos);
    return title.trim();
  }

  static Pair<String?, String> splitChannel(String text) {
    int pos = text.indexOf(r',http');
    if (pos < 0) {
      // not a channel line
      return Pair(null, text);
    }
    // fetch channel name
    String name = text.substring(0, pos);
    name = name.trim();
    // cut the head
    pos += 1;  // skip ','
    text = text.substring(pos);
    return Pair(name, text);
  }

  static Pair<Uri?, String?> splitStream(String text) {
    Uri? url;
    String? label;
    List<String> array = text.split(r'$');
    if (array.length == 1) {
      url = LiveStream.parseUri(text.trim());
    } else {
      assert(array.length == 2, 'stream info error: $text');
      String first = array[0].trim();
      String second = array[1].trim();
      // check for url
      if (first.indexOf(r'://') > 0) {
        url = LiveStream.parseUri(first);
        label = second;
      } else if (second.indexOf(r'://') > 0) {
        url = LiveStream.parseUri(second);
        label = first;
      }
    }
    return Pair(url, label);
  }

}
