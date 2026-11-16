/*
 * Copyright (c) 2023-2026, Albert Moky. All rights reserved.
 * Use of this source code is governed by a MIT-style license
 * that can be found in the LICENSE file.
 */
// Demo for the LNC package - Log, Notification & Cache (rendered on the
// pub.dev "Example" tab).
//
// Run with: dart run --enable-asserts example/lnc_example.dart
// (asserts must be enabled, otherwise debug/info/warning are silent)
//
// Exercises the four log levels with level / color / caller options and
// lazy closure messages, the notification center with broadcast and
// async observers, and the memory cache with life span, renewal, expiry
// and purging, printing one line per step.
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';
import 'package:lnc/cache.dart';

/// Sample class to show how the `Logging` mixin
/// prefixes each line with the class name.
class Greeter with Logging {

  void greet(String name) => logInfo('Hello, $name!');
}

/// Sample observer to listen to the 'welcome' notification.
class Guest with Logging implements Observer {

  @override
  Future<void> onReceiveNotification(Notification notification) async {
    logInfo('${notification.sender} says: ${notification.userInfo?['message']}');
  }
}

/// Sample async observer, e.g. saving the notification into a database.
class Archiver with Logging implements Observer {
  final List<Notification> inbox = [];

  @override
  Future<void> onReceiveNotification(Notification notification) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    inbox.add(notification);
    logInfo('archived: ${notification.name}');
  }
}

/// Sample printer that redirects the log output into a list,
/// e.g. to show in-app or attach to a crash report.
class MemoryPrinter extends LogPrinter {
  final List<String> lines = [];

  @override
  void println(String x, {required String tag, required LogCaller caller}) {
    lines.add(x);
  }
}

void main() async {
  //
  //  1. Log
  //
  Log.level = Log.DEBUG;    // RELEASE shows warnings & errors only
  Log.colorful = true;      // pretty ANSI colors in the terminal

  Log.debug('debug message');
  Log.info('info message');
  Log.warning('warning message');
  Log.error('error message');

  Greeter().greet('LNC');

  // resolve & show where the log is called from
  Log.showCaller = true;
  Log.info('this line shows the caller location');
  Log.showCaller = false;

  // in RELEASE, debug & info are silent
  Log.level = Log.RELEASE;
  Log.debug('you cannot see me in RELEASE');
  Log.error('but you can see me');

  // a nullary closure is built lazily: it only runs when the level
  // is enabled, so expensive interpolations are skipped when suppressed
  Log.level = Log.DEBUG;
  Log.info(() => 'now: ${DateTime.now()}');   // the common way

  int built = 0;
  String lazy() {
    built++;
    return 'lazy message #$built';
  }

  Log.debug(lazy);          // built now -> 'lazy message #1'

  Log.level = Log.RELEASE;
  Log.debug(lazy);          // suppressed -> the closure never runs

  Log.error(lazy);          // error passes RELEASE -> 'lazy message #2'
  Log.level = Log.DEBUG;
  Log.info('closure built $built times in total; '
      'the suppressed call never ran');

  // long messages are shortened in the middle by Log.MAX_LEN,
  // so a huge payload never floods the console
  Log.MAX_LEN = 160;
  Log.info('a long response: ${'x' * 1000}');
  Log.MAX_LEN = 1024;       // back to the library default

  //
  //  2. Notification
  //
  NotificationCenter center = NotificationCenter();
  Guest guest = Guest();
  Archiver archiver = Archiver();
  center.addObserver(guest, 'welcome');
  center.addObserver(archiver, 'welcome');   // all observers get the broadcast

  await center.postNotification('welcome', 'LNC', {'message': 'Hello, observers!'});
  Log.info('archived ${archiver.inbox.length} notification(s) in total');

  center.removeObserver(guest);
  center.removeObserver(archiver);
  await center.postNotification('welcome', 'LNC');   // nobody is listening now

  //
  //  3. Cache
  //
  CacheManager manager = CacheManager();
  CachePool<String, String> pool = manager.getPool('greetings');

  pool.updateValue('hello', 'world', 1);      // alive for 1 second
  pool.updateValue('bye', 'cruel world', 1);  // alive for 1 second
  pool.fetch('hello')!.holder.renewal(3);     // 'hello' gets 3 more seconds

  Log.info('cached: hello = ${pool.fetch('hello')?.value}, bye = ${pool.fetch('bye')?.value}');

  await Future.delayed(const Duration(milliseconds: 2100));

  Log.info('after 2.1s: hello = ${pool.fetch('hello')?.value}, bye = ${pool.fetch('bye')?.value}');

  // fetch a missing key -> null
  Log.info('missing: ${pool.fetch('no-such-key')?.value ?? '(not cached)'}');

  // erase a key explicitly
  pool.updateValue('temp', 'to be erased', 60);
  pool.erase('temp');
  Log.info('erased "temp": ${pool.fetch('temp')?.value ?? '(gone)'}');

  int count = manager.purge(null);            // clear deprecated holders
  Log.info('purged $count deprecated holder(s)');
}
