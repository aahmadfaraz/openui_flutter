import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

import 'budget_fixture.dart';

Object? eval(String program, [Map<String, Object?>? state]) {
  final p = OpenUiProgram.parse(program);
  return OpenUiEvaluator(
    p,
    state ?? {},
    signatures: OpenUiLibrary.standard.signatures,
  ).evaluateRoot();
}

void main() {
  group('splitOpenUi', () {
    test('separates the lead sentence from an unfenced program', () {
      final split = splitOpenUi(budgetAnswer);
      expect(split.before, startsWith("You're not overspending"));
      expect(split.program, startsWith('root = Stack('));
      expect(split.program, endsWith('"number"}]'));
      expect(split.after, isEmpty);
    });

    test('keeps markdown after the program as trailing prose', () {
      final split = splitOpenUi(
        'Intro\n\nroot = Stack([t])\nt = TextContent("Hi")\n\nHope that helps!',
      );
      expect(split.program, 'root = Stack([t])\nt = TextContent("Hi")');
      expect(split.after, 'Hope that helps!');
    });

    test('a plain markdown answer (dev backend, 2026-10-16) has none', () {
      final split = splitOpenUi('The capital of Japan is **Tokyo**.');
      expect(split.hasProgram, isFalse);
      expect(split.before, 'The capital of Japan is **Tokyo**.');
    });

    test('plain markdown has no program', () {
      final split = splitOpenUi('# Title\n\nJust text, x = 2 is fine.');
      expect(split.hasProgram, isFalse);
      expect(split.before, '# Title\n\nJust text, x = 2 is fine.');
    });

    test('ignores a program inside a code fence', () {
      const md = 'Example:\n```\nroot = Stack([a])\n```\n';
      expect(splitOpenUi(md).hasProgram, isFalse);
    });

    test('holds back a half-streamed "root" line', () {
      final split = splitOpenUi('Here you go.\n\nroo', isStreaming: true);
      expect(split.hasProgram, isFalse);
      expect(split.before, 'Here you go.\n');
    });

    test('pulls \$state declared just above root into the program', () {
      final split = splitOpenUi(
        r'Hi'
        '\n'
        r'$open = false'
        '\nroot = Stack([])',
      );
      expect(
        split.program,
        r'$open = false'
        '\nroot = Stack([])',
      );
    });
  });

  group('parse + evaluate', () {
    test('the budget answer resolves forward references', () {
      final root = eval(splitOpenUi(budgetAnswer).program!)! as OpenUiElement;
      expect(root.type, 'Stack');
      expect(root.string('gap'), 'l');
      final children = root.list('children');
      expect(children, hasLength(5));
      final row1 = children[1]! as OpenUiElement;
      expect(row1.boolean('wrap'), isTrue);
      final donutCard = row1.list('children').first! as OpenUiElement;
      final chart =
          ((donutCard.list('children').first! as OpenUiElement).list(
                'children',
              )[1]!
              as OpenUiElement);
      expect(chart.type, 'PieChart');
      expect(chart.string('variant'), 'donut');
      expect(chart.list('values'), hasLength(12));
    });

    test('Button actions keep their steps', () {
      final root =
          eval(
                'root = Buttons([b])\nb = Button("Go", Action([@ToAssistant("hello")]))',
              )!
              as OpenUiElement;
      final button = root.list('buttons').single! as OpenUiElement;
      final action = button['action']! as OpenUiAction;
      expect(action.steps.single.name, 'ToAssistant');
    });

    test('streaming: an unterminated tail is auto-closed', () {
      final root =
          eval('root = Stack([t, u])\nt = TextContent("Hel')! as OpenUiElement;
      final kids = root.list('children');
      expect((kids[0]! as OpenUiElement).string('text'), 'Hel');
      expect(kids[1], isNull); // `u` hasn't streamed in yet
    });

    test('array pluck, @Filter, @Count and @Sort', () {
      const data =
          'data = {rows: [{n: "a", s: "open", v: 3}, {n: "b", s: "done", v: 9}, {n: "c", s: "open", v: 1}]}';
      expect(eval('root = data.rows.n\n$data'), ['a', 'b', 'c']);
      expect(
        eval('root = @Count(@Filter(data.rows, "s", "==", "open"))\n$data'),
        2,
      );
      expect(eval('root = @Sort(data.rows, "v", "desc").n\n$data'), [
        'b',
        'a',
        'c',
      ]);
    });

    test('@Each binds the loop variable', () {
      final out =
          eval('root = @Each(xs, "x", Tag(x.name))\nxs = [{name: "a"}, {name: "b"}]')!
              as List;
      expect(out.map((t) => (t! as OpenUiElement).string('text')), ['a', 'b']);
    });

    test('string concat, ternary and \$state', () {
      expect(eval(r'root = "Count: " + $n', {r'$n': 3}), 'Count: 3');
      expect(eval(r'root = $n > 2 ? "big" : "small"', {r'$n': 3}), 'big');
      expect(eval('root = 7 / 2'), 3.5);
      expect(eval('root = "" + 4.0'), '4');
    });

    test('bare \$state args become two-way bindings', () {
      final el =
          eval(r'root = Callout("info", "T", "D", $show)', {r'$show': true})!
              as OpenUiElement;
      expect(el.binding('visible')?.name, r'$show');
      expect(el['visible'], isTrue);
    });

    test('a malformed statement is dropped, the rest still renders', () {
      final root =
          eval('root = Stack([a, b])\na = TextContent("ok")\nb = (((')!
              as OpenUiElement;
      expect((root.list('children')[0]! as OpenUiElement).string('text'), 'ok');
    });

    test('a reference cycle evaluates to null instead of overflowing', () {
      expect(eval('root = a\na = b\nb = a'), isNull);
    });
  });
}
