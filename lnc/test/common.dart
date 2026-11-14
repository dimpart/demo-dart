import 'package:lnc/log.dart';

/// ANSI escape sequence for colored terminal output.
final RegExp _ansi = RegExp(r'\x1B\[[0-9;]*m');

/// A half-cut ANSI escape sequence at the end of a truncated text.
final RegExp _ansiTail = RegExp(r'\x1B\[[0-9;]*$');

/// Echoes a formatted log line to the console in a compact form:
/// line breaks are flattened, and overlong messages are truncated,
/// while the colors are kept for terminal rendering.
void echoLog(String line, {int maxLength = 200}) {
  String text = line.replaceAll('\n', ' ⏎ ').trim();
  int total = text.replaceAll(_ansi, '').length;
  if (total > maxLength) {
    // cut the raw text, drop a half-cut escape, then close the color
    text = text.substring(0, maxLength).replaceAll(_ansiTail, '');
    if (line.contains(_ansi)) {
      text += Logger.clearColor;
    }
    text += ' … ($total chars)';
  }
  print('  ↪ $text');
}

/// Printer that records the full formatted lines for assertions,
/// and echoes a tidied copy to the console for visibility.
class RecordingPrinter extends LogPrinter {
  final List<String> lines = [];

  @override
  void println(String x, {required String tag, required LogCaller caller}) {
    lines.add(x);
    echoLog(x);
  }
}

/// Printer that only echoes tidied lines - used by suites that don't
/// assert on the log output, but still want the library logs visible.
class TidyPrinter extends LogPrinter {
  @override
  void println(String x, {required String tag, required LogCaller caller}) {
    echoLog(x);
  }
}
