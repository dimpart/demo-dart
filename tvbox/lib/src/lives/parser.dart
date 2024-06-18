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

import 'channel.dart';
import 'factory.dart';
import 'genre.dart';
import 'stream.dart';


class LiveParser {
  LiveParser({LiveFactory? factory})
      : factory = factory ?? LiveFactory();

  final LiveFactory factory;

  List<LiveGenre> parse(String text) => parseLines(text.split('\n'));

  // protected
  List<LiveGenre> parseLines(List<String> lines) {
    List<LiveGenre> groups = [];
    LiveGenre current = factory.newGenre('');
    String text;
    String? title;              // group title
    String? name;               // channel name
    Pair<String?, List<Uri>> pair;
    LiveChannel channel;
    Set<LiveStream> streams;
    //
    //  parse each line
    //
    for (String item in lines) {
      text = item.trim();
      if (text.isEmpty) {
        continue;
      } else if (text.startsWith(r'#')) {
        continue;
      } else if (text.startsWith(r'//')) {
        continue;
      }
      //
      //  1. check group name
      //
      title = fetchGenre(text);
      if (title != null) {
        // add current group
        if (current.isNotEmpty) {
          groups.add(current);
        }
        // create next group
        current = factory.newGenre(title);
        continue;
      }
      //
      //  2. parse channel
      //
      pair = fetchChannel(text);
      name = pair.first;
      if (name == null) {
        assert(false, 'channel error: $item');
        continue;
      }
      channel = factory.newChannel(name);
      //
      //  3. create streams
      //
      streams = {};
      for (Uri url in pair.second) {
        streams.add(factory.newStream(url));
      }
      channel.addStreams(streams);
      current.addChannel(channel);
    }
    // add last group
    if (current.isNotEmpty) {
      groups.add(current);
    }
    return groups;
  }

  //
  //  Text Parsers
  //

  /// get group title
  static String? fetchGenre(String text) {
    int pos = text.indexOf(r',#genre#');
    if (pos < 0) {
      return null;
    }
    String title = text.substring(0, pos);
    return title.trim();
  }

  /// get channel name & stream sources
  static Pair<String?, List<Uri>> fetchChannel(String text) {
    int pos = text.indexOf(r',http');
    if (pos < 0) {
      // not a channel line
      return Pair(null, []);
    }
    // fetch channel name
    String name = text.substring(0, pos);
    name = name.trim();
    // cut the head
    pos += 1;  // skip ','
    text = text.substring(pos);
    // cut the tail
    pos = text.indexOf(r'$');
    if (pos > 0) {
      text = text.substring(0, pos);
    }
    // fetch sources
    return Pair(name, splitStreams(text));
  }

  /// split stream sources with '#'
  static List<Uri> splitStreams(String text) {
    List<String> array = text.split(r'#');
    Uri? url;
    List<Uri> sources = [];
    for (String item in array) {
      url = LiveStream.parseUri(item);
      if (url != null) {
        sources.add(url);
      }
    }
    return sources;
  }

}
