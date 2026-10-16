import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Markdown through the theme's [OpenUiThemeData.markdownBuilder] when the
/// app supplies one, else [OpenUiBasicMarkdown].
class OpenUiMarkdown extends StatelessWidget {
  const OpenUiMarkdown(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final builder = OpenUiTheme.of(context).markdownBuilder;
    if (builder != null) return builder(context, text, style);
    return OpenUiBasicMarkdown(text, style: style);
  }
}

/// A small dependency-free markdown renderer: headings, bullet and numbered
/// lists, block quotes, fenced code, and inline bold, italic, ~~strike~~,
/// `code` and links; a single newline is a line break, as on the web.
/// Enough for the short markdown openui-lang components carry.
class OpenUiBasicMarkdown extends StatefulWidget {
  const OpenUiBasicMarkdown(
    this.text, {
    super.key,
    required this.style,
    this.inline = false,
    this.textAlign,
  });

  final String text;
  final TextStyle style;

  /// Only inline markup: [text] is one paragraph, no blocks.
  final bool inline;
  final TextAlign? textAlign;

  @override
  State<OpenUiBasicMarkdown> createState() => _OpenUiBasicMarkdownState();
}

class _OpenUiBasicMarkdownState extends State<OpenUiBasicMarkdown> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  static final _inline = RegExp(
    r'(\*\*|__)(.+?)\1|(?<![\w*])(\*|_)(?!\s)(.+?)\3(?![\w*])|`([^`]+)`|\[([^\]]+)\]\(([^)\s]+)\)|~~(.+?)~~',
  );

  List<InlineSpan> _spans(String text, TextStyle style, OpenUiThemeData t) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m[2] != null) {
        spans.add(
          TextSpan(
            children: _spans(m[2]!, style, t),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (m[4] != null) {
        spans.add(
          TextSpan(
            children: _spans(m[4]!, style, t),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m[5] != null) {
        spans.add(
          TextSpan(
            text: m[5],
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: (style.fontSize ?? 15) * .9,
              backgroundColor: t.surfaceSunk,
            ),
          ),
        );
      } else if (m[8] != null) {
        spans.add(
          TextSpan(
            children: _spans(m[8]!, style, t),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        );
      } else {
        final url = m[7]!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          };
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: m[6],
            style: TextStyle(color: t.primary),
            recognizer: recognizer,
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  Widget _rich(String text, TextStyle style, OpenUiThemeData t) => Text.rich(
    TextSpan(style: style, children: _spans(text, style, t)),
    textAlign: widget.textAlign,
  );

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final t = OpenUiTheme.of(context);
    final style = widget.style;
    if (widget.inline) return _rich(widget.text, style, t);
    final base = style.fontSize ?? t.baseFontSize;
    final blocks = <Widget>[];
    final paragraph = <String>[];

    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add(_rich(paragraph.join('\n'), style, t));
      paragraph.clear();
    }

    final lines = widget.text.split('\n');
    final heading = RegExp(r'^(#{1,6})\s+(.*)$');
    final bullet = RegExp(r'^\s*[-*+]\s+(.*)$');
    final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        flush();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i++]);
        }
        blocks.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: t.surfaceSunk,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code.join('\n'),
                style: style.copyWith(
                  fontFamily: 'monospace',
                  fontSize: base * .85,
                ),
              ),
            ),
          ),
        );
        continue;
      }
      if (line.trim().isEmpty) {
        flush();
        continue;
      }
      final h = heading.firstMatch(line);
      if (h != null) {
        flush();
        final level = h[1]!.length;
        blocks.add(
          _rich(
            h[2]!,
            style.copyWith(
              fontSize: base * (level <= 1 ? 1.3 : (level == 2 ? 1.2 : 1.08)),
              fontWeight: FontWeight.w700,
              color: t.textStrong,
            ),
            t,
          ),
        );
        continue;
      }
      final b = bullet.firstMatch(line);
      final n = b == null ? numbered.firstMatch(line) : null;
      if (b != null || n != null) {
        flush();
        blocks.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: n != null ? 22 : 16,
                child: Text(n != null ? '${n[1]}.' : '•', style: style),
              ),
              Expanded(child: _rich(b?[1] ?? n![2]!, style, t)),
            ],
          ),
        );
        continue;
      }
      if (line.startsWith('>')) {
        flush();
        blocks.add(
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: t.primary, width: 3)),
            ),
            child: _rich(
              line.replaceFirst(RegExp(r'^>\s?'), ''),
              style.copyWith(color: t.textMuted),
              t,
            ),
          ),
        );
        continue;
      }
      paragraph.add(line.trim());
    }
    flush();
    if (blocks.length == 1) return blocks.single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: base * .45),
          blocks[i],
        ],
      ],
    );
  }
}

/// One run of inline markdown — **bold**, *italic*, ~~strike~~, `code`,
/// links — for values like entity-list cells and option descriptions.
/// Plain text skips the parser. Honours the ambient `DefaultTextStyle`
/// line limits, like [Text].
class OpenUiInlineMarkdown extends StatelessWidget {
  const OpenUiInlineMarkdown(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  static final _markup = RegExp(r'[*_`~\[]');

  @override
  Widget build(BuildContext context) {
    if (!_markup.hasMatch(text)) {
      return Text(text, style: style, textAlign: textAlign);
    }
    return OpenUiBasicMarkdown(
      text,
      style: style,
      inline: true,
      textAlign: textAlign,
    );
  }
}
