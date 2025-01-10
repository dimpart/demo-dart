/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
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
 * =============================================================================
 */
import 'dart:typed_data';

import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';
import 'package:dimsdk/dimsdk.dart';

import '../common/session.dart';
import '../group/shared.dart';

import '../common/protocol/password.dart';


abstract class Emitter with Logging {

  Future<User?> get currentUser;

  Transmitter? get messenger;

  ///  Send text message to receiver
  ///
  /// @param text     - text message
  /// @param extra
  /// @param receiver - receiver ID
  /// @return packed messages
  Future<Pair<InstantMessage?, ReliableMessage?>> sendText(String text, {
    Map<String, Object>? extra,
    required ID receiver
  }) async {
    assert(text.isNotEmpty, 'text message should not empty');
    // create text content
    TextContent content = TextContent.create(text);
    // check text format
    if (checkMarkdown(text)) {
      logInfo('send text as markdown: $text => $receiver');
      content['format'] = 'markdown';
    } else {
      logInfo('send text as plain: $text -> $receiver');
    }
    // set extra params
    if (extra != null) {
      content.addAll(extra);
    }
    return await sendContent(content, receiver: receiver);
  }
  // protected
  bool checkMarkdown(String text) {
    // check links
    if (text.contains('://')) {
      return true;
    }
    // check code blocks
    int pos = text.indexOf('```');
    if (pos >= 0) {
      pos += 3;
      int next = text.codeUnitAt(pos);
      if (next != '`'.codeUnitAt(0)) {
        pos = text.indexOf('```', pos + 1);
        if (pos > 0) {
          return true;
        }
      }
    }
    // check headlines
    List<String> array = text.split('\n');
    for (String line in array) {
      if (line.startsWith('> ')) {
        return true;
      // } else if (line.startsWith('# ')) {
      //   return true;
      } else if (line.startsWith('## ')) {
        return true;
      } else if (line.startsWith('### ')) {
        return true;
      }
    }
    // TODO: other format
    return false;
  }

  ///  Send voice message to receiver
  ///
  /// @param mp4      - voice file
  /// @param filename  - '$encoded.mp4'
  /// @param duration - length
  /// @param extra
  /// @param receiver - receiver ID
  Future<Pair<InstantMessage?, ReliableMessage?>> sendVoice(Uint8List mp4, {
    required String filename, required double duration,
    Map<String, Object>? extra,
    required ID receiver
  }) async {
    assert(mp4.isNotEmpty, 'voice data should not empty');
    TransportableData ted = TransportableData.create(mp4);
    // create audio content
    AudioContent content = FileContent.audio(
      data: ted,
      filename: filename,
    );
    // set voice data length & duration
    content['length'] = mp4.length;
    content['duration'] = duration;
    // set extra params
    if (extra != null) {
      content.addAll(extra);
    }
    return await sendContent(content, receiver: receiver);
  }

  ///  Send picture to receiver
  ///
  /// @param jpeg      - image data
  /// @param filename  - '$encoded.jpeg'
  /// @param thumbnail - image thumbnail
  /// @param extra
  /// @param receiver  - receiver ID
  Future<Pair<InstantMessage?, ReliableMessage?>> sendPicture(Uint8List jpeg, {
    required String filename, required PortableNetworkFile? thumbnail,
    Map<String, Object>? extra,
    required ID receiver
  }) async {
    assert(jpeg.isNotEmpty, 'image data should not empty');
    TransportableData ted = TransportableData.create(jpeg);
    // create image content
    ImageContent content = FileContent.image(
      data: ted,
      filename: filename,
    );
    // set image data length
    content['length'] = jpeg.length;
    // set extra params
    if (thumbnail != null) {
      content.thumbnail = thumbnail;
    }
    if (extra != null) {
      content.addAll(extra);
    }
    return await sendContent(content, receiver: receiver);
  }

  ///  Send movie to receiver
  ///
  /// @param url      - video URL
  /// @param snapshot - cover URL
  /// @param title    - video title
  /// @param filename
  /// @param extra
  /// @param receiver - receiver ID
  Future<Pair<InstantMessage?, ReliableMessage?>> sendMovie(Uri url, {
    required PortableNetworkFile? snapshot, required String? title,
    String? filename, Map<String, Object>? extra,
    required ID receiver
  }) async {
    // create video content
    VideoContent content = FileContent.video(
      filename: filename,
      url: url,
      password: Password.plainKey,
    );
    // set extra params
    if (snapshot != null) {
      content.snapshot = snapshot;
    }
    if (title != null) {
      content['title'] = title;
    }
    if (extra != null) {
      content.addAll(extra);
    }
    return await sendContent(content, receiver: receiver);
  }

  /// Send content
  Future<Pair<InstantMessage?, ReliableMessage?>> sendContent(Content content, {
    ID? sender, required ID receiver, int priority = 0
  }) async {
    // check sender
    if (sender == null) {
      User? user = await currentUser;
      sender = user?.identifier;
      if (sender == null) {
        assert(false, 'failed to get current user');
        return Pair(null, null);
      }
    }
    // check receiver
    if (receiver.isGroup) {
      assert(content.group == null || content.group == receiver, 'group ID error: $receiver, $content');
      content.group = receiver;
    }
    // pack message
    Envelope envelope = Envelope.create(sender: sender, receiver: receiver);
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    // send message
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: 0);
    if (rMsg == null && !receiver.isGroup) {
      logWarning('not send yet (type=${content.type}): $receiver');
    }
    return Pair(iMsg, rMsg);
  }

  /// Send message
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    //
    //  1. check file content
    //
    Content content = iMsg.content;
    if (content is FileContent) {
      // To avoid traffic congestion, sending a message with file data inside is not allowed,
      // you should upload the encrypted data to a CDN server first, and then
      // send the message with a download URL to the receiver.
      bool waiting = await handleFileContent(content, iMsg, priority: priority);
      if (waiting) {
        // waiting to upload
        // after file data uploaded, call this method again
        return null;
      }
    }
    assert(iMsg.content['data'] == null, 'cannot send this message: $iMsg');
    //
    //  2. check receiver
    //
    ID receiver = iMsg.receiver;
    logInfo('sending message (type=${iMsg.content.type}): ${iMsg.sender} -> $receiver');
    if (receiver.isUser) {
      // send out directly
      return await messenger?.sendInstantMessage(iMsg, priority: priority);
    }
    // send by group manager
    SharedGroupManager manager = SharedGroupManager();
    return await manager.sendInstantMessage(iMsg, priority: priority);
  }

  //  Send file content asynchronously
  //  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  //    Step 1: save origin data into a cache directory;
  //    Step 2: save instant message without 'content.data';
  //    Step 3: encrypt the data with password;
  //    Step 4: upload the encrypted data and get a download URL;
  //    Step 5: resend the instant message with the download URL.

  /// Encrypted & upload file data to CDN
  ///
  /// @param content - file content
  /// @param iMsg    - message to be sent
  /// @return true on waiting upload
  Future<bool> handleFileContent(FileContent content, InstantMessage iMsg, {int priority = 0});

}
