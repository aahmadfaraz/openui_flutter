/// openui-lang: the declarative UI language chat answers can carry instead of
/// (or next to) markdown. A Dart port of the subset of upstream
/// `@openuidev/lang-core` that our backend's system prompt uses — line
/// statements, positional component args, `$state`, references that may be
/// used before they are defined, operators, array pluck, the data builtins
/// and `Action([...])` steps.
///
/// Parsing is lenient by design, like upstream: a statement that doesn't
/// parse is dropped, an unresolved reference evaluates to null, and
/// [autoClose] lets a half-streamed program parse so the UI fills in while
/// the answer arrives.
library;

// ── Tokens ──────────────────────────────────────────────────────────────────

enum _T {
  ident,
  stateVar,
  str,
  num,
  newline,
  lParen,
  rParen,
  lBrack,
  rBrack,
  lBrace,
  rBrace,
  comma,
  colon,
  equals,
  eqEq,
  notEq,
  not,
  greater,
  greaterEq,
  less,
  lessEq,
  and,
  or,
  plus,
  minus,
  star,
  slash,
  percent,
  question,
  dot,
  at,
}

class _Token {
  const _Token(this.t, [this.v]);
  final _T t;
  final Object? v;
}

List<_Token> _tokenize(String src) {
  final out = <_Token>[];
  var i = 0;
  final n = src.length;

  bool isIdentStart(int c) =>
      (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
  bool isIdentPart(int c) => isIdentStart(c) || (c >= 48 && c <= 57);
  bool isDigit(int c) => c >= 48 && c <= 57;

  while (i < n) {
    final c = src[i];
    if (c == ' ' || c == '\t' || c == '\r') {
      i++;
      continue;
    }
    if (c == '\n') {
      out.add(const _Token(_T.newline));
      i++;
      continue;
    }
    final two = i + 1 < n ? src.substring(i, i + 2) : '';
    switch (two) {
      case '==':
        out.add(const _Token(_T.eqEq));
        i += 2;
        continue;
      case '!=':
        out.add(const _Token(_T.notEq));
        i += 2;
        continue;
      case '>=':
        out.add(const _Token(_T.greaterEq));
        i += 2;
        continue;
      case '<=':
        out.add(const _Token(_T.lessEq));
        i += 2;
        continue;
      case '&&':
        out.add(const _Token(_T.and));
        i += 2;
        continue;
      case '||':
        out.add(const _Token(_T.or));
        i += 2;
        continue;
    }
    const single = {
      '(': _T.lParen,
      ')': _T.rParen,
      '[': _T.lBrack,
      ']': _T.rBrack,
      '{': _T.lBrace,
      '}': _T.rBrace,
      ',': _T.comma,
      ':': _T.colon,
      '=': _T.equals,
      '!': _T.not,
      '>': _T.greater,
      '<': _T.less,
      '+': _T.plus,
      '-': _T.minus,
      '*': _T.star,
      '/': _T.slash,
      '%': _T.percent,
      '?': _T.question,
      '@': _T.at,
    };
    final cu = c.codeUnitAt(0);
    if (c == '.' && !(i + 1 < n && isDigit(src.codeUnitAt(i + 1)))) {
      out.add(const _Token(_T.dot));
      i++;
      continue;
    }
    final punct = single[c];
    if (punct != null) {
      out.add(_Token(punct));
      i++;
      continue;
    }
    if (c == '"' || c == "'") {
      final quote = c;
      final buf = StringBuffer();
      i++;
      while (i < n && src[i] != quote) {
        if (src[i] == '\\' && i + 1 < n) {
          final e = src[i + 1];
          i += 2;
          switch (e) {
            case 'n':
              buf.write('\n');
            case 't':
              buf.write('\t');
            case 'r':
              buf.write('\r');
            case 'u':
              if (i + 4 <= n) {
                final code = int.tryParse(src.substring(i, i + 4), radix: 16);
                if (code != null) {
                  buf.writeCharCode(code);
                  i += 4;
                  break;
                }
              }
              buf.write('u');
            default:
              buf.write(e);
          }
          continue;
        }
        buf.write(src[i]);
        i++;
      }
      i++; // closing quote
      out.add(_Token(_T.str, buf.toString()));
      continue;
    }
    if (isDigit(cu) || c == '.') {
      final start = i;
      while (i < n && (isDigit(src.codeUnitAt(i)) || src[i] == '.')) {
        i++;
      }
      if (i < n && (src[i] == 'e' || src[i] == 'E')) {
        i++;
        if (i < n && (src[i] == '+' || src[i] == '-')) i++;
        while (i < n && isDigit(src.codeUnitAt(i))) {
          i++;
        }
      }
      out.add(_Token(_T.num, num.tryParse(src.substring(start, i)) ?? 0));
      continue;
    }
    if (c == r'$' && i + 1 < n && isIdentStart(src.codeUnitAt(i + 1))) {
      final start = i;
      i++;
      while (i < n && isIdentPart(src.codeUnitAt(i))) {
        i++;
      }
      out.add(_Token(_T.stateVar, src.substring(start, i)));
      continue;
    }
    if (isIdentStart(cu)) {
      final start = i;
      while (i < n && isIdentPart(src.codeUnitAt(i))) {
        i++;
      }
      out.add(_Token(_T.ident, src.substring(start, i)));
      continue;
    }
    // Anything else (stray unicode outside a string, backticks…) is noise.
    i++;
  }
  return out;
}

// ── AST ─────────────────────────────────────────────────────────────────────

sealed class OpenUiNode {
  const OpenUiNode();
}

class LitNode extends OpenUiNode {
  const LitNode(this.value);
  final Object? value;
}

class ArrNode extends OpenUiNode {
  const ArrNode(this.items);
  final List<OpenUiNode> items;
}

class ObjNode extends OpenUiNode {
  const ObjNode(this.entries);
  final List<(String, OpenUiNode)> entries;
}

/// A bare identifier: a statement reference or an `@Each` loop variable.
class RefNode extends OpenUiNode {
  const RefNode(this.name);
  final String name;
}

/// `$name` — reactive state.
class StateNode extends OpenUiNode {
  const StateNode(this.name);
  final String name;
}

/// `TypeName(args…)` — a component (or `Action`).
class CompNode extends OpenUiNode {
  const CompNode(this.name, this.args);
  final String name;
  final List<OpenUiNode> args;
}

/// `@Name(args…)` — a builtin function or action step.
class BuiltinNode extends OpenUiNode {
  const BuiltinNode(this.name, this.args);
  final String name;
  final List<OpenUiNode> args;
}

class MemberNode extends OpenUiNode {
  const MemberNode(this.target, this.field);
  final OpenUiNode target;
  final String field;
}

class IndexNode extends OpenUiNode {
  const IndexNode(this.target, this.index);
  final OpenUiNode target;
  final OpenUiNode index;
}

class UnaryNode extends OpenUiNode {
  const UnaryNode(this.op, this.operand);
  final String op;
  final OpenUiNode operand;
}

class BinaryNode extends OpenUiNode {
  const BinaryNode(this.op, this.left, this.right);
  final String op;
  final OpenUiNode left;
  final OpenUiNode right;
}

class TernaryNode extends OpenUiNode {
  const TernaryNode(this.cond, this.then, this.otherwise);
  final OpenUiNode cond;
  final OpenUiNode then;
  final OpenUiNode otherwise;
}

// ── Parser ──────────────────────────────────────────────────────────────────

class _ParseError implements Exception {}

class _Parser {
  _Parser(this.tokens);
  final List<_Token> tokens;
  var pos = 0;

  _Token? get peek => pos < tokens.length ? tokens[pos] : null;
  bool at(_T t) => peek?.t == t;

  _Token expect(_T t) {
    if (!at(t)) throw _ParseError();
    return tokens[pos++];
  }

  bool accept(_T t) {
    if (!at(t)) return false;
    pos++;
    return true;
  }

  OpenUiNode parseExpression() => _ternary();

  OpenUiNode _ternary() {
    final cond = _or();
    if (!accept(_T.question)) return cond;
    final then = _ternary();
    expect(_T.colon);
    return TernaryNode(cond, then, _ternary());
  }

  OpenUiNode _or() {
    var left = _and();
    while (accept(_T.or)) {
      left = BinaryNode('||', left, _and());
    }
    return left;
  }

  OpenUiNode _and() {
    var left = _equality();
    while (accept(_T.and)) {
      left = BinaryNode('&&', left, _equality());
    }
    return left;
  }

  OpenUiNode _equality() {
    var left = _comparison();
    while (true) {
      if (accept(_T.eqEq)) {
        left = BinaryNode('==', left, _comparison());
      } else if (accept(_T.notEq)) {
        left = BinaryNode('!=', left, _comparison());
      } else {
        return left;
      }
    }
  }

  OpenUiNode _comparison() {
    var left = _additive();
    const ops = {
      _T.greater: '>',
      _T.greaterEq: '>=',
      _T.less: '<',
      _T.lessEq: '<=',
    };
    while (peek != null && ops.containsKey(peek!.t)) {
      final op = ops[tokens[pos++].t]!;
      left = BinaryNode(op, left, _additive());
    }
    return left;
  }

  OpenUiNode _additive() {
    var left = _multiplicative();
    while (true) {
      if (accept(_T.plus)) {
        left = BinaryNode('+', left, _multiplicative());
      } else if (accept(_T.minus)) {
        left = BinaryNode('-', left, _multiplicative());
      } else {
        return left;
      }
    }
  }

  OpenUiNode _multiplicative() {
    var left = _unary();
    const ops = {_T.star: '*', _T.slash: '/', _T.percent: '%'};
    while (peek != null && ops.containsKey(peek!.t)) {
      final op = ops[tokens[pos++].t]!;
      left = BinaryNode(op, left, _unary());
    }
    return left;
  }

  OpenUiNode _unary() {
    if (accept(_T.not)) return UnaryNode('!', _unary());
    if (accept(_T.minus)) return UnaryNode('-', _unary());
    return _postfix(_primary());
  }

  OpenUiNode _postfix(OpenUiNode node) {
    while (true) {
      if (accept(_T.dot)) {
        final field = expect(_T.ident).v as String;
        node = MemberNode(node, field);
      } else if (accept(_T.lBrack)) {
        final index = parseExpression();
        expect(_T.rBrack);
        node = IndexNode(node, index);
      } else {
        return node;
      }
    }
  }

  List<OpenUiNode> _args(_T close) {
    final args = <OpenUiNode>[];
    while (!at(close)) {
      if (peek == null) throw _ParseError();
      args.add(parseExpression());
      if (!accept(_T.comma)) break;
    }
    expect(close);
    return args;
  }

  OpenUiNode _primary() {
    final tok = peek;
    if (tok == null) throw _ParseError();
    switch (tok.t) {
      case _T.str:
      case _T.num:
        pos++;
        return LitNode(tok.v);
      case _T.stateVar:
        pos++;
        return StateNode(tok.v as String);
      case _T.lParen:
        pos++;
        final inner = parseExpression();
        expect(_T.rParen);
        return inner;
      case _T.lBrack:
        pos++;
        return ArrNode(_args(_T.rBrack));
      case _T.lBrace:
        pos++;
        final entries = <(String, OpenUiNode)>[];
        while (!at(_T.rBrace)) {
          final key = peek;
          if (key == null || (key.t != _T.ident && key.t != _T.str)) {
            throw _ParseError();
          }
          pos++;
          expect(_T.colon);
          entries.add((key.v as String, parseExpression()));
          if (!accept(_T.comma)) break;
        }
        expect(_T.rBrace);
        return ObjNode(entries);
      case _T.at:
        pos++;
        final name = expect(_T.ident).v as String;
        expect(_T.lParen);
        return BuiltinNode(name, _args(_T.rParen));
      case _T.ident:
        pos++;
        final name = tok.v as String;
        switch (name) {
          case 'true':
            return const LitNode(true);
          case 'false':
            return const LitNode(false);
          case 'null':
            return const LitNode(null);
        }
        if (accept(_T.lParen)) return CompNode(name, _args(_T.rParen));
        return RefNode(name);
      default:
        throw _ParseError();
    }
  }
}

/// Closes an unterminated string and any open brackets so a program that is
/// still streaming in parses; upstream `autoClose`.
String autoClose(String input) {
  final stack = <String>[];
  String? inStr;
  var esc = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (esc) {
      esc = false;
      continue;
    }
    if (inStr != null) {
      if (c == '\\') {
        esc = true;
      } else if (c == inStr) {
        inStr = null;
      }
      continue;
    }
    if (c == '"' || c == "'") {
      inStr = c;
    } else if (c == '(' || c == '[' || c == '{') {
      stack.add(c);
    } else if (stack.isNotEmpty &&
        ((c == ')' && stack.last == '(') ||
            (c == ']' && stack.last == '[') ||
            (c == '}' && stack.last == '{'))) {
      stack.removeLast();
    }
  }
  if (inStr == null && stack.isEmpty) return input;
  final out = StringBuffer(input);
  if (inStr != null) {
    if (esc) out.write('\\');
    out.write(inStr);
  }
  for (final open in stack.reversed) {
    out.write(open == '(' ? ')' : (open == '[' ? ']' : '}'));
  }
  return out.toString();
}

/// A parsed program: every `name = expr` statement, keyed by name. State
/// declarations keep their `$` (`$count`).
class OpenUiProgram {
  OpenUiProgram(this.statements);

  final Map<String, OpenUiNode> statements;

  OpenUiNode? get root => statements['root'];

  /// Initial values of the `$state` declarations.
  Map<String, OpenUiNode> get stateDefaults => {
    for (final e in statements.entries)
      if (e.key.startsWith(r'$')) e.key: e.value,
  };

  /// Parses [source]; a still-streaming tail is auto-closed first. Lines that
  /// aren't `identifier = expression` and statements that fail to parse are
  /// skipped rather than failing the whole program.
  static OpenUiProgram parse(String source) {
    final tokens = _tokenize(autoClose(source));
    final statements = <String, OpenUiNode>{};
    var pos = 0;
    while (pos < tokens.length) {
      while (pos < tokens.length && tokens[pos].t == _T.newline) {
        pos++;
      }
      if (pos >= tokens.length) break;
      final id = tokens[pos];
      final isStatement =
          (id.t == _T.ident || id.t == _T.stateVar) &&
          pos + 1 < tokens.length &&
          tokens[pos + 1].t == _T.equals;
      if (!isStatement) {
        while (pos < tokens.length && tokens[pos].t != _T.newline) {
          pos++;
        }
        continue;
      }
      pos += 2;
      // Expression tokens run to the next newline outside brackets; a
      // ternary may continue on the next line (`? …` / `: …`).
      final expr = <_Token>[];
      var depth = 0;
      var ternary = 0;
      while (pos < tokens.length) {
        final t = tokens[pos].t;
        if (t == _T.newline && depth <= 0) {
          var peek = pos + 1;
          while (peek < tokens.length && tokens[peek].t == _T.newline) {
            peek++;
          }
          final next = peek < tokens.length ? tokens[peek].t : null;
          if (next == _T.question || (next == _T.colon && ternary > 0)) {
            pos++;
            continue;
          }
          break;
        }
        if (t == _T.newline) {
          pos++;
          continue;
        }
        if (t == _T.lParen || t == _T.lBrack || t == _T.lBrace) {
          depth++;
        } else if ((t == _T.rParen || t == _T.rBrack || t == _T.rBrace) &&
            depth > 0) {
          depth--;
        } else if (t == _T.question && depth == 0) {
          ternary++;
        } else if (t == _T.colon && depth == 0 && ternary > 0) {
          ternary--;
        }
        expr.add(tokens[pos++]);
      }
      if (expr.isEmpty) continue;
      try {
        final parser = _Parser(expr);
        final node = parser.parseExpression();
        if (parser.pos == expr.length) statements[id.v as String] = node;
      } on _ParseError {
        // Lenient: a malformed statement is dropped, like upstream.
      }
    }
    return OpenUiProgram(statements);
  }
}

// ── Runtime values ──────────────────────────────────────────────────────────

/// A rendered component: its type and props, mapped from the positional args
/// by the component's parameter list in the [OpenUiEvaluator.signatures].
class OpenUiElement {
  const OpenUiElement(this.type, this.props);
  final String type;
  final Map<String, Object?> props;

  /// The prop's value, with a `$binding` unwrapped to its current value.
  Object? operator [](String name) {
    final v = props[name];
    return v is OpenUiBinding ? v.value : v;
  }

  /// The `$state` a prop was bound to, if any (two-way props: Modal open,
  /// Callout visible, form values).
  OpenUiBinding? binding(String name) {
    final v = props[name];
    return v is OpenUiBinding ? v : null;
  }

  String? string(String name) {
    final v = this[name];
    if (v == null) return null;
    return openUiToText(v);
  }

  bool boolean(String name, {bool fallback = false}) {
    final v = this[name];
    return v is bool ? v : fallback;
  }

  num? number(String name) => openUiToNumber(this[name]);

  List<Object?> list(String name) {
    final v = this[name];
    return v is List ? v : const [];
  }

  @override
  String toString() => '$type($props)';
}

/// A component arg written as a bare `$state` reference.
class OpenUiBinding {
  const OpenUiBinding(this.name, this.value);
  final String name;
  final Object? value;
}

/// A step inside `Action([...])`. Its args stay unevaluated until the click,
/// so `@Set($count, $count + 1)` reads the state at click time.
class OpenUiActionStep {
  const OpenUiActionStep(this.name, this.args, this.locals);
  final String name;
  final List<OpenUiNode> args;
  final Map<String, Object?> locals;
}

/// What a button (or clickable card, list item…) does when tapped.
class OpenUiAction {
  const OpenUiAction(this.steps, {this.context});

  /// Sends [message] to the assistant — what a component without its own
  /// action does with its label.
  OpenUiAction.toAssistant(String message, {this.context})
    : steps = [
        OpenUiActionStep('ToAssistant', [LitNode(message)], const {}),
      ];

  final List<OpenUiActionStep> steps;

  /// Extra lines a `@ToAssistant` step carries after its message, e.g. which
  /// card of a block was tapped (upstream's step `context`).
  final String? context;

  OpenUiAction withContext(String extra) => OpenUiAction(
    steps,
    context: context == null ? extra : '$context\n$extra',
  );
}

// ── Evaluator ───────────────────────────────────────────────────────────────

/// Evaluates a program's statements against the current `$state`. One
/// instance serves one render pass: statement values are memoized, and a
/// reference cycle evaluates to null instead of overflowing.
class OpenUiEvaluator {
  OpenUiEvaluator(this.program, this.state, {required this.signatures});

  final OpenUiProgram program;
  final Map<String, Object?> state;

  /// Each component's parameter names in positional order — what binds
  /// `Card([a], "sunk")` to `{children: [a], variant: "sunk"}`.
  final Map<String, List<String>> signatures;

  final _memo = <String, Object?>{};
  final _evaluating = <String>{};

  Object? evaluateRoot() {
    final root = program.root;
    return root == null ? null : evaluateRef('root');
  }

  Object? evaluateRef(String name) {
    if (_memo.containsKey(name)) return _memo[name];
    final node = program.statements[name];
    if (node == null || !_evaluating.add(name)) return null;
    final value = evaluate(node, const {});
    _evaluating.remove(name);
    return _memo[name] = value;
  }

  Object? evaluate(OpenUiNode node, Map<String, Object?> locals) {
    switch (node) {
      case LitNode(:final value):
        return value;
      case ArrNode(:final items):
        return [for (final item in items) evaluate(item, locals)];
      case ObjNode(:final entries):
        return {for (final (k, v) in entries) k: evaluate(v, locals)};
      case RefNode(:final name):
        if (locals.containsKey(name)) return locals[name];
        return evaluateRef(name);
      case StateNode(:final name):
        return state[name];
      case CompNode(:final name, :final args):
        if (name == 'Action') return _action(args, locals);
        return _element(name, args, locals);
      case BuiltinNode(:final name, :final args):
        return _builtin(name, args, locals);
      case MemberNode(:final target, :final field):
        final obj = evaluate(target, locals);
        if (obj is List) {
          if (field == 'length') return obj.length;
          return [for (final item in obj) item is Map ? item[field] : null];
        }
        if (obj is Map) return obj[field];
        if (obj is String && field == 'length') return obj.length;
        return null;
      case IndexNode(:final target, :final index):
        final obj = evaluate(target, locals);
        final idx = evaluate(index, locals);
        if (obj is List) {
          final i = openUiToNumber(idx)?.toInt();
          return i != null && i >= 0 && i < obj.length ? obj[i] : null;
        }
        if (obj is Map) return obj[openUiToText(idx)];
        return null;
      case UnaryNode(:final op, :final operand):
        final v = evaluate(operand, locals);
        return op == '!' ? !openUiTruthy(v) : -(openUiToNumber(v) ?? 0);
      case TernaryNode(:final cond, :final then, :final otherwise):
        return openUiTruthy(evaluate(cond, locals))
            ? evaluate(then, locals)
            : evaluate(otherwise, locals);
      case BinaryNode(:final op, :final left, :final right):
        return _binary(op, left, right, locals);
    }
  }

  OpenUiElement _element(
    String type,
    List<OpenUiNode> args,
    Map<String, Object?> locals,
  ) {
    final params = signatures[type] ?? const <String>[];
    final props = <String, Object?>{};
    for (var i = 0; i < args.length && i < params.length; i++) {
      final arg = args[i];
      final value = evaluate(arg, locals);
      props[params[i]] = arg is StateNode
          ? OpenUiBinding(arg.name, value)
          : value;
    }
    return OpenUiElement(type, props);
  }

  OpenUiAction _action(List<OpenUiNode> args, Map<String, Object?> locals) {
    final steps = <OpenUiActionStep>[];
    final list = args.isEmpty ? null : args.first;
    final nodes = list is ArrNode ? list.items : args;
    for (final step in nodes) {
      if (step is BuiltinNode) {
        steps.add(OpenUiActionStep(step.name, step.args, locals));
      } else if (step is RefNode) {
        // `onSubmit = Action([...])` assigned to a variable and spliced in.
        final value = evaluate(step, locals);
        if (value is OpenUiAction) steps.addAll(value.steps);
      }
    }
    return OpenUiAction(steps);
  }

  Object? _binary(
    String op,
    OpenUiNode leftNode,
    OpenUiNode rightNode,
    Map<String, Object?> locals,
  ) {
    final left = evaluate(leftNode, locals);
    if (op == '&&') {
      return openUiTruthy(left) ? evaluate(rightNode, locals) : left;
    }
    if (op == '||') {
      return openUiTruthy(left) ? left : evaluate(rightNode, locals);
    }
    final right = evaluate(rightNode, locals);
    num n(Object? v) => openUiToNumber(v) ?? 0;
    switch (op) {
      case '+':
        if (left is String || right is String) {
          return openUiToText(left) + openUiToText(right);
        }
        return n(left) + n(right);
      case '-':
        return n(left) - n(right);
      case '*':
        return n(left) * n(right);
      case '/':
        return n(right) == 0 ? 0 : n(left) / n(right);
      case '%':
        return n(right) == 0 ? 0 : n(left) % n(right);
      case '==':
        return openUiLooseEquals(left, right);
      case '!=':
        return !openUiLooseEquals(left, right);
      case '>':
        return n(left) > n(right);
      case '<':
        return n(left) < n(right);
      case '>=':
        return n(left) >= n(right);
      case '<=':
        return n(left) <= n(right);
    }
    return null;
  }

  Object? _builtin(
    String name,
    List<OpenUiNode> args,
    Map<String, Object?> locals,
  ) {
    // @Each is lazy: its template is evaluated once per item, with the
    // item bound to the named loop variable.
    if (name == 'Each') {
      if (args.length < 3) return const [];
      final items = evaluate(args[0], locals);
      final varName = openUiToText(evaluate(args[1], locals));
      if (items is! List) return const [];
      return [
        for (final item in items) evaluate(args[2], {...locals, varName: item}),
      ];
    }
    final values = [for (final a in args) evaluate(a, locals)];
    Object? arg(int i) => i < values.length ? values[i] : null;
    List<Object?> listArg(int i) {
      final v = arg(i);
      return v is List ? v : const [];
    }

    Iterable<num> numbers(List<Object?> list) =>
        list.map(openUiToNumber).whereType<num>();

    switch (name) {
      case 'Count':
        final v = arg(0);
        return v is List ? v.length : (v is String ? v.length : 0);
      case 'Sum':
        return numbers(listArg(0)).fold<num>(0, (a, b) => a + b);
      case 'Avg':
        final ns = numbers(listArg(0)).toList();
        return ns.isEmpty ? 0 : ns.fold<num>(0, (a, b) => a + b) / ns.length;
      case 'Min':
        final ns = numbers(listArg(0));
        return ns.isEmpty ? null : ns.reduce((a, b) => a < b ? a : b);
      case 'Max':
        final ns = numbers(listArg(0));
        return ns.isEmpty ? null : ns.reduce((a, b) => a > b ? a : b);
      case 'First':
        final l = listArg(0);
        return l.isEmpty ? null : l.first;
      case 'Last':
        final l = listArg(0);
        return l.isEmpty ? null : l.last;
      case 'Round':
        final v = openUiToNumber(arg(0)) ?? 0;
        final digits = (openUiToNumber(arg(1)) ?? 0).toInt().clamp(0, 10);
        return num.parse(v.toStringAsFixed(digits));
      case 'Abs':
        return (openUiToNumber(arg(0)) ?? 0).abs();
      case 'Floor':
        return (openUiToNumber(arg(0)) ?? 0).floor();
      case 'Ceil':
        return (openUiToNumber(arg(0)) ?? 0).ceil();
      case 'Filter':
        final field = openUiToText(arg(1));
        final op = arg(2) == null ? '==' : openUiToText(arg(2));
        final target = arg(3);
        return listArg(0).where((item) {
          final v = field.isEmpty ? item : (item is Map ? item[field] : null);
          num nn(Object? x) => openUiToNumber(x) ?? 0;
          return switch (op) {
            '==' => openUiLooseEquals(v, target),
            '!=' => !openUiLooseEquals(v, target),
            '>' => nn(v) > nn(target),
            '<' => nn(v) < nn(target),
            '>=' => nn(v) >= nn(target),
            '<=' => nn(v) <= nn(target),
            'contains' => openUiToText(
              v,
            ).toLowerCase().contains(openUiToText(target).toLowerCase()),
            _ => false,
          };
        }).toList();
      case 'Sort':
        final field = openUiToText(arg(1));
        final desc = openUiToText(arg(2)).toLowerCase() == 'desc';
        final sorted = [...listArg(0)];
        Object? key(Object? item) =>
            field.isEmpty ? item : (item is Map ? item[field] : null);
        sorted.sort((a, b) {
          final ka = key(a), kb = key(b);
          final na = openUiToNumber(ka), nb = openUiToNumber(kb);
          final c = (na != null && nb != null)
              ? na.compareTo(nb)
              : openUiToText(ka).compareTo(openUiToText(kb));
          return desc ? -c : c;
        });
        return sorted;
    }
    // Action steps written outside Action([...]) and unknown builtins.
    return null;
  }
}

// ── Coercions (JS-flavoured, matching upstream) ─────────────────────────────

bool openUiTruthy(Object? v) {
  if (v == null || v == false) return false;
  if (v is num) return v != 0 && !v.isNaN;
  if (v is String) return v.isNotEmpty;
  return true;
}

num? openUiToNumber(Object? v) {
  if (v is num) return v;
  if (v is bool) return v ? 1 : 0;
  if (v is String) return num.tryParse(v.trim().replaceAll(',', ''));
  return null;
}

/// How a value reads as text: whole numbers without a trailing `.0`.
String openUiToText(Object? v) {
  if (v == null) return '';
  if (v is double) {
    if (v.isFinite && v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }
  if (v is List) return v.map(openUiToText).join(',');
  return v.toString();
}

bool openUiLooseEquals(Object? a, Object? b) {
  if (a == null || b == null) return a == b;
  if (a is num || b is num) {
    final na = openUiToNumber(a), nb = openUiToNumber(b);
    if (na != null && nb != null) return na == nb;
  }
  return openUiToText(a) == openUiToText(b);
}
