/// Splits a chat answer into the markdown around it and the openui-lang
/// program inside it.
///
/// The backend's prompt has the model write the program as plain lines with
/// no code fence, starting at `root = Stack([...])`, with an optional short
/// markdown sentence before or after:
///
/// ```text
/// You're not overspending: …
///
/// root = Stack([header, row1], "column", "l")
/// header = …
/// ```
class OpenUiSplit {
  const OpenUiSplit({required this.before, this.program, this.after = ''});

  /// Markdown ahead of the program (the whole answer when there's none).
  final String before;

  /// The openui-lang program, or null when the answer is plain markdown.
  final String? program;

  /// Markdown after the program's last statement.
  final String after;

  bool get hasProgram => program != null;
}

final _rootLine = RegExp(r'^\s*root\s*=\s*([A-Z]\w*)?\s*(\(|$)');
final _statementLine = RegExp(r'^\s*\$?[A-Za-z_]\w*\s*=(?!=)');
final _stateLine = RegExp(r'^\s*\$[A-Za-z_]\w*\s*=(?!=)');
final _ternaryContinuation = RegExp(r'^\s*[?:]');
final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})');

/// A last line that could still grow into `root = …` — held back while
/// streaming so a lone "root" doesn't flash up as prose.
final _rootPrefix = RegExp(r'^\s*(r|ro|roo|root(\s*=?\s*\w*)?)$');

OpenUiSplit splitOpenUi(String answer, {bool isStreaming = false}) {
  final lines = answer.split('\n');
  var inFence = false;
  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    if (_fence.hasMatch(lines[i])) {
      inFence = !inFence;
      continue;
    }
    if (!inFence && _rootLine.hasMatch(lines[i])) {
      start = i;
      break;
    }
  }

  if (start < 0) {
    if (isStreaming && lines.length > 1 && _rootPrefix.hasMatch(lines.last)) {
      return OpenUiSplit(before: lines.sublist(0, lines.length - 1).join('\n'));
    }
    if (isStreaming && lines.length == 1 && _rootPrefix.hasMatch(lines.first)) {
      return const OpenUiSplit(before: '');
    }
    return OpenUiSplit(before: answer);
  }

  // `$state` declarations written just above root belong to the program.
  while (start > 0 && _stateLine.hasMatch(lines[start - 1])) {
    start--;
  }

  // The program runs while lines are statements, blank, a ternary carried
  // onto the next line, or inside an open bracket / string.
  var end = start;
  var depth = 0;
  String? inString;
  for (var i = start; i < lines.length; i++) {
    final line = lines[i];
    final continuing = depth > 0 || inString != null;
    if (!continuing &&
        i != start &&
        line.trim().isNotEmpty &&
        !_statementLine.hasMatch(line) &&
        !_ternaryContinuation.hasMatch(line)) {
      break;
    }
    end = i + 1;
    var escaped = false;
    for (var j = 0; j < line.length; j++) {
      final c = line[j];
      if (inString != null) {
        if (escaped) {
          escaped = false;
        } else if (c == '\\') {
          escaped = true;
        } else if (c == inString) {
          inString = null;
        }
        continue;
      }
      if (c == '"') {
        inString = c;
      } else if (c == '(' || c == '[' || c == '{') {
        depth++;
      } else if ((c == ')' || c == ']' || c == '}') && depth > 0) {
        depth--;
      }
    }
  }

  return OpenUiSplit(
    before: lines.sublist(0, start).join('\n').trimRight(),
    program: lines.sublist(start, end).join('\n').trimRight(),
    after: lines.sublist(end).join('\n').trim(),
  );
}
