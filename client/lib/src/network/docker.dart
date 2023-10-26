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

import '../common/session.dart';


abstract interface class Arrival {

  Uint8List get payload;

}
abstract interface class Departure {

}


class DockerStatus {

  static const int kError     = -1;
  static const int kInit      =  0;
  static const int kPreparing =  1;
  static const int kReady     =  2;

}


abstract interface class Docker {

  SocketAddress get remoteAddress;
  SocketAddress get localAddress;

}


abstract interface class DockerDelegate {

  ///  Callback when new package received
  ///
  /// @param ship        - income data package container
  /// @param docker      - connection docker
  Future<void> onDockerReceived(Arrival ship, Docker docker);

  ///  Callback when package sent
  ///
  /// @param ship        - outgo data package container
  /// @param docker      - connection docker
  Future<void> onDockerSent(Departure ship, Docker docker);

  ///  Callback when failed to send package
  ///
  /// @param error       - error message
  /// @param ship        - outgo data package container
  /// @param docker      - connection docker
  Future<void> onDockerFailed(Error error, Departure ship, Docker docker);

  ///  Callback when connection error
  ///
  /// @param error       - error message
  /// @param ship        - outgo data package container
  /// @param docker      - connection docker
  Future<void> onDockerError(Error error, Departure ship, Docker docker);

  ///  Callback when connection status changed
  ///
  /// @param previous    - old status
  /// @param current     - new status
  /// @param docker      - connection docker
  Future<void> onDockerStatusChanged(int previous, int current, Docker docker);

}
