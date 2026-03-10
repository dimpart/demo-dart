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
import 'package:dim_plugins/dim_plugins.dart';

import '../../../common/protocol/app.dart';

import 'handler.dart';


/// Factory for CustomizedContentHandler
abstract interface class CustomizedContentFilter {

  ///  Get CustomizedContentHandler for the CustomizedContent
  ///
  /// @param content - customized content
  /// @param rMsg    - network message
  /// @return CustomizedContentHandler
  CustomizedContentHandler filterContent(CustomizedContent content, ReliableMessage rMsg);

}


/// CustomizedContent Extensions
/// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CustomizedContentFilter _filter = AppCustomizedFilter();

extension CustomizedContentExtension on MessageExtensions {

  CustomizedContentFilter get customizedFilter => _filter;
  set customizedFilter(CustomizedContentFilter filter) => _filter = filter;

}


/// General CustomizedContent Filter
/// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class AppCustomizedFilter implements CustomizedContentFilter {

  CustomizedContentHandler defaultHandler = BaseCustomizedContentHandler();

  final Map<String, CustomizedContentHandler> _handlers = {};

  void setContentHandler({
    required String app, required String mod,
    required CustomizedContentHandler handler
  }) => _handlers['$app:$mod'] = handler;

  // protected
  CustomizedContentHandler? getContentHandler({
    required String app, required String mod,
  }) => _handlers['$app:$mod'];

  @override
  CustomizedContentHandler filterContent(CustomizedContent content, ReliableMessage rMsg) {
    // String app = content.application;
    String app = content.getString('app') ?? '';
    String mod = content.module;
    var handler = getContentHandler(app: app, mod: mod);
    if (handler != null) {
      return handler;
    }
    // if the application has too many modules, I suggest you to
    // use different handler to do the jobs for each module.
    throw defaultHandler;
  }

}
