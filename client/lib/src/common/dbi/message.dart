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
import 'package:dimsdk/dimsdk.dart';
import 'package:object_key/object_key.dart';


///  Message DBI
///  ~~~~~~~~~~~
abstract interface class ReliableMessageDBI {

  ///  Get network messages
  ///
  /// @param receiver actual receiver
  /// @param start    start position for loading message
  /// @param limit    max count for loading message
  /// @return partial messages and remaining count, 0 means there are all messages cached
  Future<Pair<List<ReliableMessage>, int>> getReliableMessages(ID receiver,
      {int start = 0, int? limit});

  Future<bool> cacheReliableMessage(ID receiver, ReliableMessage rMsg);

  Future<bool> removeReliableMessage(ID receiver, ReliableMessage rMsg);
}


///  Message DBI
///  ~~~~~~~~~~~
abstract interface class CipherKeyDBI implements CipherKeyDelegate {

}


///  Message DBI
///  ~~~~~~~~~~~
abstract interface class GroupKeysDBI {

  Map getGroupKeys({required ID group, required ID sender});

  bool saveGroupKeys({required ID group, required ID sender, required Map keys});

}


///  Message DBI
///  ~~~~~~~~~~~
abstract interface class MessageDBI implements ReliableMessageDBI, CipherKeyDBI, GroupKeysDBI {

}
