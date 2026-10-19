import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/src/reveal.dart';

void main() {
  const frame = Duration(milliseconds: 16);

  test('structure appears at once; string text costs time', () {
    final r = OpenUiReveal(minRate: 60)..reset('root = TextContent("Hello")');
    r.advance(Duration.zero);
    // Everything up to and including the opening quote is free.
    expect(r.visible, 'root = TextContent("');
    r.advance(frame); // 60/s * 16ms ≈ 1 char
    expect(r.visible.length, lessThan('root = TextContent("Hello'.length));
    for (var i = 0; i < 100; i++) {
      r.advance(frame);
    }
    expect(r.done, isTrue);
    expect(r.visible, 'root = TextContent("Hello")');
  });

  test('once the stream ends, a large backlog lands within a second', () {
    final long = 'root = TextContent("${'x' * 3000}")';
    final r = OpenUiReveal(catchUp: const Duration(milliseconds: 600))
      ..reset(long);
    var t = Duration.zero;
    while (!r.done && t < const Duration(seconds: 3)) {
      r.advance(frame, hurry: true);
      t += frame;
    }
    expect(r.done, isTrue);
    expect(t, lessThan(const Duration(milliseconds: 1200)));
  });

  test('while streaming it keeps pace without dumping the backlog', () {
    final r = OpenUiReveal(catchUp: const Duration(milliseconds: 600))
      ..reset('root = TextContent("${'x' * 600}")');
    r.advance(frame);
    // ~1000 chars/s at this backlog: a frame shows a handful, not all.
    expect(r.visible.length, lessThan(60));
    expect(r.done, isFalse);
  });

  test('continuations keep the cursor; rewrites jump to the end', () {
    final r = OpenUiReveal()..reset('root = TextContent("ab');
    r.advance(const Duration(seconds: 1));
    expect(r.done, isTrue);
    r.retarget('root = TextContent("abcdef")');
    expect(r.done, isFalse);
    expect(r.visible, 'root = TextContent("ab');
    r.retarget('something else entirely');
    expect(r.done, isTrue);
  });

  test('escaped quotes stay inside the string', () {
    final r = OpenUiReveal(minRate: 1000)..reset(r'a = T("say \"hi\" now")');
    r.advance(const Duration(seconds: 1));
    expect(r.visible, r'a = T("say \"hi\" now")');
  });
}
