/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
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

import 'package:dimp/dimp.dart';
import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/lnc.dart';
import 'package:object_key/object_key.dart';

import 'compat/compatible.dart';
import 'facebook.dart';
import 'session.dart';

abstract class CommonMessenger extends Messenger implements Transmitter {
  CommonMessenger(this._session, this._facebook, this._database)
      : _packer = null, _processor = null;

  final Session _session;
  final CommonFacebook _facebook;
  final CipherKeyDelegate _database;
  Packer? _packer;
  Processor? _processor;

  Session get session => _session;

  @override
  EntityDelegate get entityDelegate => _facebook;

  CommonFacebook get facebook => _facebook;

  @override
  CipherKeyDelegate? get cipherKeyDelegate => _database;

  @override
  Packer? get packer => _packer;
  set packer(Packer? messagePacker) => _packer = messagePacker;

  @override
  Processor? get processor => _processor;
  set processor(Processor? messageProcessor) => _processor = messageProcessor;

  @override
  Future<Uint8List?> encryptKey(Uint8List key, ID receiver, InstantMessage iMsg) async {
    try {
      return await super.encryptKey(key, receiver, iMsg);
    } catch (e, st) {
      // FIXME:
      Log.error('failed to encrypt key for receiver: $receiver, error: $e');
      Log.debug('failed to encrypt key for receiver: $receiver, error: $e, $st');
      return null;
    }
  }

  @override
  Future<Uint8List?> serializeKey(SymmetricKey password, InstantMessage iMsg) async {
    // TODO: reuse message key

    // 0. check message key
    Object? reused = password['reused'];
    Object? digest = password['digest'];
    if (reused == null && digest == null) {
      // flags not exist, serialize it directly
      return await super.serializeKey(password, iMsg);
    }
    // 1. remove before serializing key
    password.remove('reused');
    password.remove('digest');
    // 2. serialize key without flags
    Uint8List? data = await super.serializeKey(password, iMsg);
    // 3. put them back after serialized
    if (Converter.getBool(reused, false)!) {
      password['reused'] = true;
    }
    if (digest != null) {
      password['digest'] = digest;
    }
    // OK
    return data;
  }

  @override
  Future<Uint8List> serializeContent(Content content, SymmetricKey password, InstantMessage iMsg) async {
    if (content is Command) {
      content = Compatible.fixCommand(content);
    }
    return await super.serializeContent(content, password, iMsg);
  }

  @override
  Future<Content?> deserializeContent(Uint8List data, SymmetricKey password, SecureMessage sMsg) async {
    Content? content = await super.deserializeContent(data, password, sMsg);
    if (content is Command) {
      content = Compatible.fixCommand(content);
    }
    return content;
  }

  //
  //  Interfaces for Transmitting Message
  //

  @override
  Future<Pair<InstantMessage, ReliableMessage?>> sendContent(Content content,
      {required ID? sender, required ID receiver, int priority = 0}) async {
    if (sender == null) {
      User? current = await facebook.currentUser;
      assert(current != null, 'current suer not set');
      sender = current!.identifier;
    }
    Envelope env = Envelope.create(sender: sender, receiver: receiver);
    InstantMessage iMsg = InstantMessage.create(env, content);
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: priority);
    return Pair(iMsg, rMsg);
  }

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    // 0. check cycled message
    if (iMsg.sender == iMsg.receiver) {
      Log.warning('drop cycled message: ${iMsg.content} '
          '${iMsg.sender} => ${iMsg.receiver}, ${iMsg.group}');
      return null;
    } else {
      Log.debug('send instant message (type=${iMsg.content.type}): '
          '${iMsg.sender} => ${iMsg.receiver}, ${iMsg.group}');
    }
    // 1. encrypt message
    SecureMessage? sMsg = await encryptMessage(iMsg);
    if (sMsg == null) {
      // assert(false, 'public key not found?');
      return null;
    }
    // 2. sign message
    ReliableMessage? rMsg = await signMessage(sMsg);
    if (rMsg == null) {
      // TODO: set msg.state = error
      throw Exception('failed to sign message: $sMsg');
    }
    // 3. send message
    if (await sendReliableMessage(rMsg, priority: priority)) {
      return rMsg;
    } else {
      // failed
      return null;
    }
  }

  @override
  Future<bool> sendReliableMessage(ReliableMessage rMsg, {int priority = 0}) async {
    // 0. check cycled message
    if (rMsg.sender == rMsg.receiver) {
      Log.warning('drop cycled message: ${rMsg.sender} => ${rMsg.receiver}, ${rMsg.group}');
      return false;
    }
    // 1. serialize message
    Uint8List? data = await serializeMessage(rMsg);
    if (data == null) {
      assert(false, 'failed to serialize message: $rMsg');
      return false;
    }
    // 2. call gate keeper to send the message data package
    //    put message package into the waiting queue of current session
    return session.queueMessagePackage(rMsg, data, priority: priority);
  }

}
