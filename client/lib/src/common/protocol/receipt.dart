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
import 'package:dimp/dimp.dart';


///  Receipt command message: {
///      type : 0x88,
///      sn   : 456,
///
///      command : "receipt",
///      text    : "...",  // text message
///      origin  : {       // original message envelope
///          sender    : "...",
///          receiver  : "...",
///          time      : 0,
///          sn        : 123,
///          signature : "..."
///      }
///  }
class ReceiptCommand extends BaseCommand {
  ReceiptCommand(super.dict) : _env = null;

  /// original message envelope
  Envelope? _env;

  static const String kReceipt = 'receipt';

  ReceiptCommand.from(
      {String? text, Envelope? envelope, int? sn, String? signature})
      : super.fromName(kReceipt) {
    // text message
    if (text != null) {
      this['text'] = text;
    }
    _env = envelope;
    // envelope of the message responding to
    Map origin;
    if (envelope == null) {
      origin = {};
    } else {
      origin = envelope.toMap();
    }
    // sn of the message responding to
    if (sn != null) {
      origin['sn'] = sn;
    }
    // signature of the message responding to
    if (signature != null) {
      origin['signature'] = signature;
    }
    if (origin.isNotEmpty) {
      this['origin'] = origin;
    }
  }

  //-------- setters/getters --------

  String? get text => getString('text');

  Map? _origin() => this['origin'];

  Envelope? get originalEnvelope {
    if (_env == null) {
      // origin: { sender: "...", receiver: "...", time: 0 }
      Map? origin = _origin();
      if (origin != null && origin.containsKey('sender')) {
        _env = Envelope.parse(origin);
      }
    }
    return _env;
  }

  int get originalSerialNumber {
    Map? origin = _origin();
    if (origin == null) {
      return 0;
    }
    var sn = origin['sn'];
    return sn ?? 0;
  }

  String? get originalSignature {
    Map? origin = _origin();
    if (origin == null) {
      return null;
    }
    return origin['signature'];
  }

  bool matchMessage(InstantMessage iMsg) {
    // check signature
    String? sig1 = originalSignature;
    if (sig1 != null) {
      // if contains signature, check it
      String? sig2 = iMsg.getString('signature');
      if (sig2 != null) {
        if (sig1.length > 8) {
          sig1 = sig1.substring(0, 8);
        }
        if (sig2.length > 8) {
          sig2 = sig2.substring(0, 8);
        }
        return sig1 == sig2;
      }
    }
    // check envelope
    Envelope? env1 = originalEnvelope;
    if (env1 != null) {
      // if contains envelope, check it
      return env1 == iMsg.envelope;
    }
    // check serial number
    // (only the original message's receiver can know this number)
    return originalSerialNumber == iMsg.content.sn;
  }

  //
  //  Factory method
  //

  ///  Create receipt with text message and origin message envelope
  ///
  /// @param text - message text
  /// @param rMsg - origin message
  /// @return ReceiptCommand
  static ReceiptCommand create(String? text, ReliableMessage? rMsg) {
    Envelope? env;
    if (rMsg != null) {
      Map info = rMsg.copyMap(false);
      info.remove('data');
      info.remove('key');
      info.remove('keys');
      info.remove('meta');
      info.remove('visa');
      env = Envelope.parse(info);
    }
    return ReceiptCommand.from(text: text, envelope: env);
  }
}
