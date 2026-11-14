import 'common.dart';
import 'package:lnc/log.dart';
import 'package:test/test.dart';

/// Sample class using the `Logging` mixin.
class Foo with Logging {}

RecordingPrinter printer = RecordingPrinter();

void main() {
  group('Log level filtering', () {

    setUp(() {
      // `Log.*` are global statics, reset them before each case
      printer = RecordingPrinter();
      Log.logger = DefaultLogger(printer);
      Log.level = Log.DEBUG;
      Log.MAX_LEN = 0;
      Log.colorful = true;
      Log.showTime = false;
      Log.showCaller = false;
      LogPrinter.chunkLength = 1000;
      LogPrinter.limitLength = -1;
    });

    test('Log.DEBUG outputs all four levels', () {
      Log.debug('msg-debug');
      Log.info('msg-info');
      Log.warning('msg-warning');
      Log.error('msg-error');

      expect(printer.lines, hasLength(4));
      expect(printer.lines[0], contains(' DEBUG '));
      expect(printer.lines[1], contains('msg-info'));
      expect(printer.lines[2], contains('WARNING'));
      expect(printer.lines[3], contains(' ERROR '));
    });

    test('Log.RELEASE suppresses debug and info', () {
      Log.level = Log.RELEASE;
      Log.debug('msg-debug');
      Log.info('msg-info');
      Log.warning('msg-warning');
      Log.error('msg-error');

      expect(printer.lines, hasLength(2));
      final all = printer.lines.join('\n');
      expect(all, contains('msg-warning'));
      expect(all, contains('msg-error'));
      expect(all, isNot(contains('msg-debug')));
      expect(all, isNot(contains('msg-info')));
    });

    test('Log.DEVELOP suppresses debug only', () {
      Log.level = Log.DEVELOP;
      Log.debug('msg-debug');
      Log.info('msg-info');
      Log.warning('msg-warning');
      Log.error('msg-error');

      expect(printer.lines, hasLength(3));
      expect(printer.lines.join('\n'), isNot(contains('msg-debug')));
    });

    test('level 0 suppresses everything', () {
      Log.level = 0;
      Log.debug('msg-debug');
      Log.info('msg-info');
      Log.warning('msg-warning');
      Log.error('msg-error');

      expect(printer.lines, isEmpty);
    });

    test('custom flag combination: warnings only', () {
      Log.level = Log.WARNING_FLAG;
      Log.debug('msg-debug');
      Log.info('msg-info');
      Log.warning('msg-warning');
      Log.error('msg-error');

      expect(printer.lines, hasLength(1));
      expect(printer.lines.single, contains('msg-warning'));
    });

    test('closure message is built lazily, only when level is enabled', () {
      Log.level = Log.RELEASE;
      int builds = 0;
      String build() {
        builds++;
        return 'lazy-msg';
      }

      Log.debug(build);   // suppressed -> never built
      expect(builds, 0);

      Log.error(build);   // error passes RELEASE -> built now
      expect(builds, 1);
      expect(printer.lines.single, contains('lazy-msg'));
    });

    test('null message yields an empty line', () {
      Log.info(null);
      expect(printer.lines, hasLength(1));
      expect(printer.lines.single, endsWith('| '));
    });

    test('object message is stringified with toString()', () {
      Log.info(<int>[1, 2, 3]);
      expect(printer.lines.single, contains('[1, 2, 3]'));
    });

    test('a closure returning null yields an empty line', () {
      Log.info(() => null);
      expect(printer.lines, hasLength(1));
      expect(printer.lines.single, endsWith('| '));
    });

    test('a closure may return another closure, resolved recursively', () {
      Log.info(() => () => 'nested message');
      expect(printer.lines.single, contains('nested message'));
      expect(printer.lines.single, isNot(contains('Closure')));
    });
  });

  group('Logger.shorten & Log.MAX_LEN', () {

    setUp(() {
      printer = RecordingPrinter();
      Log.logger = DefaultLogger(printer);
      Log.level = Log.DEBUG;
      Log.colorful = true;
      Log.showTime = false;
      Log.showCaller = false;
      LogPrinter.chunkLength = 10000; // keep the output on one line
      LogPrinter.limitLength = -1;
    });

    test('returns the original text when it fits maxLen', () {
      expect(Logger.shorten('short message', 1024), 'short message');
    });

    test('keeps head & tail with a total counter in the middle', () {
      final text = Logger.shorten('x' * 3000, 1024);
      expect(text.length, lessThanOrEqualTo(1024));
      expect(text, contains('total 3000 chars'));
      expect(text, startsWith('x'));
      expect(text, endsWith('x'));
    });

    test('MAX_LEN shortens long messages, 0 disables it', () {
      // 160 chars so the shortened line fits in the echo window,
      // with the middle ellipsis fully visible
      Log.MAX_LEN = 160;
      Log.debug('y' * 3000);
      expect(printer.lines.single, contains('total 3000 chars'));

      Log.MAX_LEN = 0;
      Log.debug('z' * 3000);
      expect(printer.lines.last, contains('z' * 3000));
    });
  });

  group('Output options', () {

    setUp(() {
      printer = RecordingPrinter();
      Log.logger = DefaultLogger(printer);
      Log.level = Log.DEBUG;
      Log.MAX_LEN = 0;
      Log.colorful = true;
      Log.showTime = false;
      Log.showCaller = false;
      LogPrinter.chunkLength = 1000;
      LogPrinter.limitLength = -1;
    });

    test('showTime prepends a yyyy-MM-dd HH:mm:ss timestamp', () {
      Log.showTime = true;
      Log.info('msg-with-time');
      expect(printer.lines.single,
          matches(RegExp(r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] ')));
    });

    test('showCaller appends the caller location', () {
      Log.showCaller = true;
      Log.info('msg-with-caller');
      // the traced caller points back to this test body, not to log.dart
      expect(printer.lines.single, contains('>\t'));
      expect(printer.lines.single, contains('log_test.dart:'));
    });

    test('colorful mode wraps output with ANSI color codes', () {
      Log.colorful = true;
      Log.error('colored-msg');
      expect(printer.lines.single, startsWith(Logger.fatalColor));
      expect(printer.lines.single, endsWith(Logger.clearColor));

      Log.colorful = false;
      Log.error('plain-msg');
      expect(printer.lines.last.contains('\x1B'), isFalse);
    });

    test('long output is split into chunks of chunkLength', () {
      Log.debug('a' * 2500);
      expect(printer.lines, hasLength(3));
      int total = 0;
      for (String line in printer.lines) {
        total += 'a'.allMatches(line).length;
      }
      expect(total, 2500);
      // chunks but the last one end with the carriage return mark
      expect(printer.lines.first, endsWith(LogPrinter.carriageReturn));
      expect(printer.lines.last, isNot(endsWith(LogPrinter.carriageReturn)));
    });

    test('a body exactly two chunks long prints two lines', () {
      // body = ' DEBUG  | ' (10) + 1990 = 2000 = 2 x chunkLength exactly
      Log.colorful = false;
      Log.debug('c' * 1990);
      expect(printer.lines, hasLength(2));
      int total = 0;
      for (String line in printer.lines) {
        total += 'c'.allMatches(line).length;
      }
      expect(total, 1990);
    });

    test('limitLength caps the output with an ellipsis', () {
      LogPrinter.limitLength = 100;
      Log.debug('b' * 500);
      expect(printer.lines, hasLength(1));
      expect(printer.lines.single, contains(' ...'));
    });
  });

  group('Logging mixin', () {

    setUp(() {
      printer = RecordingPrinter();
      Log.logger = DefaultLogger(printer);
      Log.level = Log.DEBUG;
      Log.MAX_LEN = 0;
      Log.colorful = true;
      Log.showTime = false;
      Log.showCaller = false;
      LogPrinter.chunkLength = 1000;
      LogPrinter.limitLength = -1;
    });

    test('className resolves to the runtime type', () {
      expect(Foo().className, 'Foo');
    });

    test('mixin helpers prefix messages with the class name', () {
      Foo().logInfo('mixin-msg');
      expect(printer.lines.single, endsWith('Foo >\tmixin-msg'));
    });

    test('mixin helpers keep the caller when showCaller is on', () {
      Log.showCaller = true;
      Foo().logDebug('located');
      final line = printer.lines.single;
      expect(line, contains(' | Foo >\tlocated'));
      expect(line, contains('log_test.dart:'));
    });
  });

  group('LogCaller', () {

    test('parses name/path/line of the frame after the anchor', () {
      final caller = LogCaller('lnc/src/log/log.dart', StackTrace.fromString([
        '#0      LogMixin.caller (package:lnc/src/log/log.dart:129:55)',
        '#1      LogMixin.debug (package:lnc/src/log/log.dart:186:7)',
        '#2      main (file:///workspace/app_test.dart:14:11)',
      ].join('\n')));

      expect(caller.name, 'main');
      expect(caller.path, 'file:///workspace/app_test.dart');
      expect(caller.line, 14);
      expect(caller.toString(), 'file:///workspace/app_test.dart:14');
    });

    test('skips anchor and asynchronous-suspension frames', () {
      final caller = LogCaller('lnc/src/log/log.dart', StackTrace.fromString([
        '#0      LogMixin.caller (package:lnc/src/log/log.dart:129:55)',
        '<asynchronous suspension>',
        '#5      testBody (package:app/main_test.dart:42:5)',
      ].join('\n')));

      expect(caller.name, 'testBody');
      expect(caller.path, 'package:app/main_test.dart');
      expect(caller.line, 42);
    });

    test('parses a trace line without a column number', () {
      final caller = LogCaller('lnc/src/log/log.dart', StackTrace.fromString([
        '#0      LogMixin.caller (package:lnc/src/log/log.dart:129:55)',
        '#1      main (file:///workspace/app_test.dart:14)',
      ].join('\n')));

      expect(caller.name, 'main');
      expect(caller.path, 'file:///workspace/app_test.dart');
      expect(caller.line, 14);
    });
  });
}
