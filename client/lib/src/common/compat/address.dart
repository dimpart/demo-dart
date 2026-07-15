/* license: https://mit-license.org
 *
 *  Ming-Ke-Ming : Decentralized User Identity Authentication
 *
 *                                Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * ==============================================================================
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
 * ==============================================================================
 */
import 'package:dim_plugins/dim_plugins.dart';
import 'package:lnc/log.dart';


class CompatibleAddressFactory extends BaseAddressFactory with Logging {

  /// Call it when received 'UIApplicationDidReceiveMemoryWarningNotification',
  /// this will remove 50% of cached objects
  ///
  /// @return number of survivors
  int reduceMemory() {
    return sharedAccountExtensions.addressCache.reduceMemory();
  }

  @override
  Address? parse(String address) {
    try {
      Address? res = super.parse(address);
      if (res != null) {
        return res;
      }
    } catch (e, st) {
      logError('address error: "$address", error: $e, $st');
      assert(false, 'invalid address: $address');
    }
    //
    //  TODO: other types of address
    //
    int len = address.length;
    if (4 <= len && len <= 64) {
      return UnknownAddress(address);
    }
    assert(false, 'invalid address: $address');
    return null;
  }

}


/// Unsupported Address
/// ~~~~~~~~~~~~~~~~~~~
class UnknownAddress extends ConstantString implements Address {
  UnknownAddress(super.string);

  @override
  int get network => 0;  // EntityType.USER;

}
