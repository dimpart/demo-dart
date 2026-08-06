/* license: https://mit-license.org
 *
 *  DIMP : Decentralized Instant Messaging Protocol
 *
 *                                Written in 2026 by Moky <albert.moky@gmail.com>
 *
 * ==============================================================================
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
 * ==============================================================================
 */
import 'package:dimsdk/dimsdk.dart';

import 'app.dart';


///  Application Customized message: {
///      "type" : i2s(0xCC),
///      "sn"   : 12345,
///      "time" : 123.45,
///
///      "app"     : "chat.dim.messenger",
///      "mod"     : "chat_history",
///      "act"     : "sync_message",
///
///      "message" : self_message
///  }
abstract interface class SyncChatContent implements CustomizedContent {

  // ignore_for_file: constant_identifier_names
  static const String APP = 'chat.dim.messenger';
  static const String MOD = 'chat_history';
  static const String ACT_SYNC = 'sync_message';

  //
  //  Factory
  //

  static CustomizedContent create(InstantMessage iMsg) {
    var content = CustomizedContent.create(app: APP, mod: MOD, act: ACT_SYNC);
    content['message'] = iMsg.toMap();
    return content;
  }
}
