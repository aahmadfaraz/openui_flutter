import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lang.dart';
import '../theme.dart';
import '../view.dart';
import 'common.dart';
import 'markdown.dart';

class OpenUiCardHeader extends StatelessWidget {
  const OpenUiCardHeader(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final title = el.string('title') ?? '';
    final subtitle = el.string('subtitle') ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: t.body(
              delta: 1,
              weight: FontWeight.w600,
              color: t.textStrong,
            ),
          ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: t.body(delta: -2, color: t.textMuted)),
        ],
      ],
    );
  }
}

class OpenUiTextContent extends StatelessWidget {
  const OpenUiTextContent(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final style = switch (el.string('size')) {
      'small' => t.body(delta: -1.5, color: t.textMuted),
      'small-heavy' => t.body(
        delta: -1.5,
        weight: FontWeight.w600,
        color: t.textStrong,
      ),
      'large' => t.body(delta: 2),
      'large-heavy' => t.body(
        delta: 5,
        weight: FontWeight.w700,
        color: t.textStrong,
        height: 1.3,
      ),
      _ => t.body(),
    };
    return OpenUiMarkdown(el.string('text') ?? '', style: style);
  }
}

class OpenUiMarkdownBlock extends StatelessWidget {
  const OpenUiMarkdownBlock(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    return OpenUiSurface(
      variant: el.string('variant') ?? 'clear',
      child: OpenUiMarkdown(
        el.string('textMarkdown') ?? '',
        style: OpenUiTheme.of(context).body(),
      ),
    );
  }
}

class OpenUiInlineHeader extends StatelessWidget {
  const OpenUiInlineHeader(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final description = el.string('description') ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          el.string('heading') ?? '',
          style: t.body(weight: FontWeight.w600, color: t.textStrong),
        ),
        if (description.isNotEmpty)
          Text(description, style: t.body(delta: -2, color: t.textMuted)),
      ],
    );
  }
}

/// Callout and TextCallout. A Callout bound to a `$visible` state fades out
/// while it's false and dismisses itself 3s after each time it shows, like
/// the web renderer.
class OpenUiCallout extends StatefulWidget {
  const OpenUiCallout(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiCallout> createState() => _OpenUiCalloutState();
}

class _OpenUiCalloutState extends State<OpenUiCallout> {
  Timer? _dismiss;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arm();
  }

  @override
  void didUpdateWidget(OpenUiCallout old) {
    super.didUpdateWidget(old);
    _arm();
  }

  void _arm() {
    final visible = widget.el.binding('visible');
    if (visible == null || !openUiTruthy(visible.value)) {
      _dismiss?.cancel();
      _dismiss = null;
      return;
    }
    if (_dismiss != null) return;
    final setVar = OpenUiScope.of(context).setVar;
    _dismiss = Timer(const Duration(seconds: 3), () {
      _dismiss = null;
      setVar(visible.name, false);
    });
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.el.binding('visible');
    if (visible == null) return _callout(context);
    final shown = openUiTruthy(visible.value);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: shown ? 1 : 0,
        child: shown
            ? _callout(context)
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  Widget _callout(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final el = widget.el;
    final variant = el.string('variant');
    final color = variant == null || variant == 'neutral'
        ? t.textMuted
        : t.variant(variant);
    final title = el.string('title') ?? '';
    final description = el.string('description') ?? '';
    final icon = el.type == 'TextCallout'
        ? null
        : switch (variant) {
            'warning' => Icons.warning_amber_rounded,
            'error' || 'danger' => Icons.error_outline_rounded,
            'success' => Icons.check_circle_outline_rounded,
            _ => Icons.info_outline_rounded,
          };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(t.radius - 2),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: t.body(
                      delta: -1,
                      weight: FontWeight.w600,
                      color: t.textStrong,
                    ),
                  ),
                if (description.isNotEmpty)
                  OpenUiMarkdown(
                    description,
                    style: t.body(delta: -1.5, color: t.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `Image(alt, src)` and `ImageBlock(src, alt)`; tap to view full screen.
/// An ImageBlock without a source renders nothing; with one it keeps a 3:2
/// frame so the answer doesn't jump when the image lands.
class OpenUiImage extends StatelessWidget {
  const OpenUiImage(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final src = el.string('src') ?? '';
    final alt = el.string('alt');
    final block = el.type == 'ImageBlock';
    if (block && src.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: src.isEmpty
          ? null
          : () => openUiShowImage(context, [(src: src, alt: alt)], 0),
      child: block
          ? AspectRatio(
              aspectRatio: 3 / 2,
              child: OpenUiNetworkImage(src: src, alt: alt),
            )
          : OpenUiNetworkImage(src: src, alt: alt, height: 200),
    );
  }
}

/// `ImageGallery(images)`: up to five tiles; the fifth shows how many more
/// there are and opens the viewer, which swipes through all of them.
class OpenUiGallery extends StatelessWidget {
  const OpenUiGallery(this.el, {super.key});

  final OpenUiElement el;

  static const _maxTiles = 5;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final images = [
      for (final m in el.list('images').whereType<Map>())
        if (openUiToText(m['src']).isNotEmpty)
          (
            src: openUiToText(m['src']),
            alt: openUiToText(m['alt']),
            details: openUiToText(m['details']),
          ),
    ];
    if (images.isEmpty) return const SizedBox.shrink();
    final all = [for (final img in images) (src: img.src, alt: img.alt)];
    final shown = images.length > _maxTiles ? _maxTiles : images.length;
    final hidden = images.length - shown;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 560 ? 3 : 2;
        final width = (constraints.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (var i = 0; i < shown; i++)
              SizedBox(
                width: width,
                child: GestureDetector(
                  onTap: () => openUiShowImage(context, all, i),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          OpenUiNetworkImage(
                            src: images[i].src,
                            alt: images[i].alt,
                            height: width * .75,
                          ),
                          if (hidden > 0 && i == shown - 1)
                            Positioned.fill(
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(
                                    t.radius - 4,
                                  ),
                                ),
                                child: Text(
                                  '+$hidden',
                                  style: t.body(
                                    delta: 4,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (images[i].details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          images[i].details,
                          style: t.body(delta: -2.5, color: t.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A full-screen, swipeable, zoomable viewer over [images].
void openUiShowImage(
  BuildContext context,
  List<({String src, String? alt})> images,
  int initial,
) {
  final theme = OpenUiTheme.of(context);
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      pageBuilder: (context, _, _) => OpenUiTheme(
        data: theme,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initial),
                itemCount: images.length,
                itemBuilder: (context, i) => InteractiveViewer(
                  child: Center(
                    child: OpenUiNetworkImage(
                      src: images[i].src,
                      alt: images[i].alt,
                      fit: BoxFit.contain,
                      radius: 0,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// `CodeBlock(language, codeString)`: monospace, scrolls sideways instead
/// of wrapping, with a copy button.
class OpenUiCode extends StatefulWidget {
  const OpenUiCode(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiCode> createState() => _OpenUiCodeState();
}

class _OpenUiCodeState extends State<OpenUiCode> {
  Timer? _reset;
  var _copied = false;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    _reset?.cancel();
    setState(() => _copied = true);
    _reset = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final lang = widget.el.string('language') ?? '';
    final code = widget.el.string('codeString') ?? '';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surfaceSunk,
        borderRadius: BorderRadius.circular(t.radius - 4),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lang,
                    style: t.body(delta: -3, color: t.textFaint),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: _copied ? 'Copied' : 'Copy code',
                  onPressed: code.isEmpty ? null : () => _copy(code),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      key: ValueKey(_copied),
                      color: _copied ? t.success : t.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SelectableText(
              code,
              style: t
                  .body(delta: -2, color: t.text, height: 1.45)
                  .copyWith(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Menlo', 'Courier'],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
