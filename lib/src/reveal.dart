import 'dart:math' as math;

/// Paces how much of a streaming openui-lang program is shown, so text
/// types out at a steady rate instead of landing in network-sized bursts.
///
/// Only what the user reads costs time: characters inside string literals
/// advance at the current rate, while structure — component names, numbers,
/// references, punctuation — is revealed instantly. Cards and charts appear
/// whole and their labels type in. The rate grows with the backlog, so the
/// reveal never trails the network by more than about [catchUp].
class OpenUiReveal {
  OpenUiReveal({
    this.minRate = 90,
    this.catchUp = const Duration(milliseconds: 600),
  });

  /// Slowest reveal, in string characters per second.
  final double minRate;

  /// How long a backlog takes to drain at most.
  final Duration catchUp;

  String _target = '';
  int _shown = 0;
  String? _quote;
  bool _escaped = false;
  double _budget = 0;

  /// The full program received so far.
  String get target => _target;

  /// The part to render now.
  String get visible => _target.substring(0, _shown);

  bool get done => _shown >= _target.length;

  /// Starts from nothing (a turn that streams in) or, with [revealed], from
  /// all of [source] (history, or a rewrite that isn't a continuation).
  void reset(String source, {bool revealed = false}) {
    _target = source;
    _shown = revealed ? source.length : 0;
    _quote = null;
    _escaped = false;
    _budget = 0;
  }

  /// More of the program arrived. A continuation of what is shown keeps the
  /// cursor where it is; anything else jumps to the end.
  void retarget(String source) {
    if (source.length >= _shown && source.startsWith(visible)) {
      _target = source;
    } else {
      reset(source, revealed: true);
    }
  }

  /// Shows everything at once.
  void finish() {
    _shown = _target.length;
    _quote = null;
    _escaped = false;
    _budget = 0;
  }

  /// Advances by [dt]; [hurry] (the stream ended) drains fast. Returns
  /// whether anything new became visible.
  bool advance(Duration dt, {bool hurry = false}) {
    final backlog = _target.length - _shown;
    if (backlog <= 0) return false;
    final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
    final window = catchUp.inMicroseconds / Duration.microsecondsPerSecond;
    // Streaming: proportional to the backlog, which keeps a steady,
    // smooth lag behind the network. Hurrying (the stream ended): a short
    // window and a high floor, so the rest lands quickly instead of easing
    // out over seconds.
    final rate = hurry
        ? math.max(minRate * 6, backlog / (window / 3))
        : math.max(minRate, backlog / window);
    // Never bank more than a frame or two of budget: after a pause the
    // reveal resumes at its pace instead of dumping a burst.
    _budget = math.min(_budget + rate * seconds, math.max(2, rate / 30));
    final start = _shown;
    while (_shown < _target.length) {
      final c = _target[_shown];
      if (_quote == null) {
        if (c == '"' || c == "'") _quote = c;
        _shown++;
        continue;
      }
      if (_budget < 1) break;
      _budget -= 1;
      _shown++;
      if (_escaped) {
        _escaped = false;
      } else if (c == r'\') {
        _escaped = true;
      } else if (c == _quote) {
        _quote = null;
      }
    }
    return _shown != start;
  }
}
