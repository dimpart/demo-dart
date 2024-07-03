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

import 'channel.dart';
import 'factory.dart';


/// Channel Group
class LiveGenre extends Dictionary {
  LiveGenre(super.dict, {String? title}) {
    // group name
    if (title != null) {
      setValue('title', title);
    }
  }

  /// Name of channel group
  String get title => getValue('title', '');

  /// Count of channels
  int get count => getValue('channels', []).length;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz title="$title" count=$count />';
  }

  @override
  bool get isEmpty => count == 0;

  @override
  bool get isNotEmpty => count > 0;

  /// Live Channels
  List<LiveChannel> get channels =>
      LiveChannel.convert(getValue('channels', []));

  set channels(Iterable<LiveChannel> items) =>
      setValue('channels', LiveChannel.revert(items));

  /// Update Channels
  bool addChannel(LiveChannel channel) {
    var array = channels;
    for (var item in array) {
      if (item.name == channel.name) {
        // same channel, merge streams
        item.addStreams(channel.streams);
        return true;
      }
    }
    array.add(channel);
    channels = array;
    return true;
  }

  bool addChannels(Iterable<LiveChannel> newChannels) {
    var array = channels;
    int count = 0;
    bool found;
    for (var item in newChannels) {
      found = false;
      for (var old in array) {
        if (old.name == item.name) {
          // same channel, merge streams
          old.addStreams(item.streams);
          found = true;
          break;
        }
      }
      if (!found) {
        array.add(item);
        count += 1;
      }
    }
    if (count == 0) {
      // nothing changed
      return false;
    }
    channels = array;
    return true;
  }

  //
  //  Factory methods
  //

  static LiveGenre? parse(Object? info) {
    if (info == null) {
      return null;
    } else if (info is LiveGenre) {
      return info;
    } else if (info is Dictionary) {
      info = info.toMap();
    }
    if (info is! Map) {
      assert(false, 'genre info error: $info');
      return null;
    }
    var factory = LiveFactory();
    return factory.createGenre(info);
  }

  static List<LiveGenre> convert(Iterable array) {
    List<LiveGenre> groups = [];
    LiveGenre? grp;
    for (var info in array) {
      grp = parse(info);
      if (grp != null) {
        groups.add(grp);
      }
    }
    return groups;
  }

  static List<Map> revert(Iterable<LiveGenre> groups) {
    List<Map> array = [];
    for (var item in groups) {
      array.add(item.toMap());
    }
    return array;
  }

}
