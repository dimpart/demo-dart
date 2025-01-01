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

import 'protocol/password.dart';


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
    if (text.contains('://')) {
      return true;
    } else if (text.contains('\n> ')) {
      return true;
    } else if (text.contains('\n# ')) {
      return true;
    } else if (text.contains('\n## ')) {
      return true;
    } else if (text.contains('\n### ')) {
      return true;
    }
    int pos = text.indexOf('```');
    if (pos >= 0) {
      pos += 3;
      int next = text.codeUnitAt(pos);
      if (next != '`'.codeUnitAt(0)) {
        return text.indexOf('```', pos + 1) > 0;
      }
    }
    return false;
  }

  ///  Send voice message to receiver
  ///
  /// @param mp4      - voice file
  /// @param filename  - '$encoded.mp4'
  /// @param duration - length
  /// @param extra
  /// @param receiver - receiver ID
  Future<bool> sendVoice(Uint8List mp4, {
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
    return await sendFileContent(content, receiver: receiver);
  }

  ///  Send picture to receiver
  ///
  /// @param jpeg      - image data
  /// @param filename  - '$encoded.jpeg'
  /// @param thumbnail - image thumbnail
  /// @param extra
  /// @param receiver  - receiver ID
  Future<bool> sendPicture(Uint8List jpeg, {
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
    return await sendFileContent(content, receiver: receiver);
  }

  ///  Send movie to receiver
  ///
  /// @param url      - video URL
  /// @param snapshot - cover URL
  /// @param title    - video title
  /// @param filename
  /// @param extra
  /// @param receiver - receiver ID
  Future<bool> sendMovie(Uri url, {
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
    return await sendFileContent(content, receiver: receiver);
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
    // check file content
    if (content is FileContent && content.data != null) {
      // To avoid traffic congestion, sending a message with file data inside is not allowed,
      // you should upload the encrypted data to a CDN server first, and then
      // send the message with a download URL to the receiver.
      bool ok = await sendFileContent(content, sender: sender, receiver: receiver, priority: priority);
      assert(ok, 'failed to send file content: $sender -> $receiver');
      return Pair(null, null);
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
    ID receiver = iMsg.receiver;
    assert(iMsg.content['data'] == null, 'cannot send this message: $iMsg');
    logInfo('sending message (type=${iMsg.content.type}): ${iMsg.sender} -> $receiver');
    if (receiver.isUser) {
      // send out directly
      return await messenger?.sendInstantMessage(iMsg, priority: priority);
    }
    // send by group manager
    SharedGroupManager manager = SharedGroupManager();
    return await manager.sendInstantMessage(iMsg, priority: priority);
  }

  /****************************************************************************/

  /// Send file content asynchronously
  /// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ///   Step 1: save origin data into a cache directory;
  ///   Step 2: save instant message without 'content.data';
  ///   Step 3: encrypt the data with password;
  ///   Step 4: upload the encrypted data and get a download URL;
  ///   Step 5: resend the instant message with the download URL.

  /// Send file content
  Future<bool> sendFileContent(FileContent content, {
    ID? sender, required ID receiver, int priority = 0
  }) async {
    // check sender
    if (sender == null) {
      User? user = await currentUser;
      sender = user?.identifier;
      if (sender == null) {
        assert(false, 'failed to get current user');
        return false;
      }
    }
    // check receiver
    if (receiver.isGroup) {
      assert(content.group == null || content.group == receiver, 'group ID error: $receiver, $content');
      content.group = receiver;
    }
    // check download URL
    if (content.url == null) {
      // file data not uploaded yet,
      // try to upload file data to get download URL,
      // and then pack a message with the URL and decrypt key to send
      return await handleFileMessage(content, sender: sender, receiver: receiver, priority: priority);
    } else if (content.data != null) {
      // FIXME:
      // download URL found, so file data should not exist here
      return await handleFileMessage(content, sender: sender, receiver: receiver, priority: priority);
    }
    // this file content's data had already been uploaded (download URL exists),
    // so pack and send it out directly.
    Envelope envelope = Envelope.create(sender: sender, receiver: receiver);
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: priority);
    if (rMsg == null && !receiver.isGroup) {
      logWarning('not send yet (type=${content.type}): $receiver');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> handleFileMessage(FileContent content, {
    required ID sender, required ID receiver, int priority = 0
  }) async {
    // check filename
    String? filename = content.filename;
    if (filename == null) {
      assert(false, 'file content error: $sender, $content');
      logError('file content error: $sender, $content');
      return false;
    }
    // check file data
    Uint8List? data = content.data;
    ///   Step 1: save origin data into a cache directory;
    if (data == null) {
      data = await getFileData(filename);
      if (data == null) {
        assert(false, 'file content error: $sender, $content');
        logError('file content error: $sender, $content');
        return false;
      }
    } else if (await cacheFileData(data, filename)) {
      // file data saved into a cache file, so
      // here we can remove it from the content.
      content.data = null;
    } else {
      logError('failed to cache file: $filename, ${data.length} byte(s)');
      return false;
    }
    assert(content.url == null, 'file content error: ${content.url}');
    // assert(content.password == null, 'file content error: ${content.password}');
    ///   Step 2: save instant message without 'content.data';
    Envelope envelope = Envelope.create(sender: sender, receiver: receiver);
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    if (await cacheInstantMessage(iMsg)) {
      // saved it temporary
    } else {
      logError('failed to save message: $iMsg');
      return false;
    }
    ///   Step 3: encrypt the data with password;
    // SymmetricKey? password = await messenger?.getEncryptKey(iMsg);
    SymmetricKey? password;
    var old = content.password;
    if (old is SymmetricKey) {
      // if password exists, reuse it
      password = old;
    } else {
      // generate a new password for each file content
      password = SymmetricKey.generate(SymmetricKey.AES);
      // NOTICE: to avoid communication key leaks,
      //         here we should generate a new key to encrypt file data,
      //         because this key will be attached into file content,
      //         if this content is forwarded, there is a security risk.
      logInfo('generated new password to upload file: $sender, $filename, $password');
      if (password == null) {
        assert(false, 'failed to generate AES key: $sender');
        return false;
      }
    }
    Uint8List encrypted = password.encrypt(data, content.toMap());
    ///   Step 4: upload the encrypted data and get a download URL;
    ///   Step 5: resend the instant message with the download URL.
    return await sendFileMessage(encrypted, filename, password, iMsg,
      content: content, sender: sender, receiver: receiver, priority: priority,
    );
  }

  // protected
  Future<bool> sendFileMessage(Uint8List encrypted, String filename, SymmetricKey password, InstantMessage iMsg, {
    required FileContent content,
    required ID sender, required ID receiver, int priority = 0,
  }) async {
    ///   Step 4: upload the encrypted data and get a download URL;
    Uri? url = await uploadFileData(encrypted, filename, sender);
    if (url == null) {
      logError('failed to upload: ${content.filename} -> $filename, ${encrypted.length} byte(s)');
      // TODO: mark message failed
      return false;
    } else {
      // upload success
      logInfo('uploaded filename: ${content.filename} -> $filename => $url');
      content.url = url;
      content.password = password;
    }
    ///   Step 5: resend the instant message with the download URL.
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: priority);
    if (rMsg == null && !receiver.isGroup) {
      logWarning('not send yet (type=${content.type}): $receiver');
      return false;
    }
    return true;
  }

  /// Save origin file data into the cache
  Future<bool> cacheFileData(Uint8List data, String filename);

  /// Load origin file data from the cache
  Future<Uint8List?> getFileData(String filename);

  /// Save instant message without 'content.data'
  Future<bool> cacheInstantMessage(InstantMessage iMsg);

  ///  Upload file data to CDN server
  ///
  /// @param encrypted - encrypted data
  /// @param filename  - original filename
  /// @param sender    - sender ID
  /// @return null on error
  Future<Uri?> uploadFileData(Uint8List encrypted, String filename, ID sender);

}
