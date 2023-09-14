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


///  ANS command: {
///      type : 0x88,
///      sn   : 123,
///
///      command : "ans",
///      names   : "...",        // query with alias(es, separated by ' ')
///      records : {             // respond with record(s)
///          "{alias}": "{ID}",
///      }
///  }
abstract class AnsCommand implements Command {

  static const String kANS = 'ans';

  List<String> get names;

  Map<String, String>? get records;
  set records(Map? info);

  //
  //  Factories
  //

  static AnsCommand query(String names) => BaseAnsCommand.from(names, null);

  static AnsCommand response(String names, Map<String, String> records) =>
      BaseAnsCommand.from(names, records);

}

class BaseAnsCommand extends BaseCommand implements AnsCommand {
  BaseAnsCommand(super.dict);

  BaseAnsCommand.from(String names, Map<String, String>? records) :
        super.fromName(AnsCommand.kANS) {
    assert(names.isNotEmpty, 'query names should not empty');
    this['names'] = names;
    if (records != null) {
      this['records'] = records;
    }
  }

  @override
  List<String> get names {
    String? string = getString('names', null);
    return string == null ? [] : string.split(' ');
  }

  @override
  Map<String, String>? get records => this['records'];

  @override
  set records(Map? info) => this['records'] = info;

}
