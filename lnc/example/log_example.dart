/* LNC : Log module example
 *
 * Run me with: `dart run --enable-asserts example/log_example.dart`
 * (asserts must be enabled, otherwise debug/info/warning are silent)
 */
import 'package:lnc/log.dart';

/// Sample class to show how the `Logging` mixin
/// prefixes each line with the class name.
class Greeter with Logging {

  void greet(String name) => logInfo('Hello, $name!');
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

Future<void> main() async {
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

  // redirect the output with a custom printer, e.g. collect the
  // lines in memory to attach them to a crash report
  MemoryPrinter memory = MemoryPrinter();
  Log.logger = DefaultLogger(memory);
  Log.warning('this line is collected in memory');

  // ... and switch back to the console
  Log.logger = DefaultLogger(LogPrinter());
  Log.info('collected ${memory.lines.length} line(s) in memory');
}
