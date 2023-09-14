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

///  Quote content: {
///      type : 0x37,
///      sn   : 123,
///
///      quote : {
///          sender : "{ID}",  // quote sender
///          content : {...},  // quote content
///      },
///      text  : "..."         // comment
///  }
abstract class QuoteContent implements Content {

  ID get quoteSender;
  Content get quoteContent;

  String get text;
  set text(String comment);

  //
  //  Factory
  //

  static QuoteContent create(ID sender, Content content) =>
      BaseQuoteContent.from(sender, content);

}

class BaseQuoteContent extends BaseContent implements QuoteContent {
  BaseQuoteContent(super.dict) : _content = null;

  BaseQuoteContent.from(ID sender, Content content)
      : super.fromType(ContentType.kQuote) {
    this['quote'] = {
      'sender' : sender.toString(),
      'content': content.toMap(),
    };
  }

  Content? _content;

  @override
  Content get quoteContent {
    _content ??= Content.parse(this['quote']['content']);
    assert(_content != null, 'quote content not found: $this');
    return _content!;
  }

  @override
  ID get quoteSender => ID.parse(this['quote']['sender'])!;

  @override
  String get text => getString('text', '')!;

  @override
  set text(String comment) => this['text'] = comment;

}
