import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lang.dart';
import '../theme.dart';
import '../view.dart';
import 'common.dart';
import 'data.dart';
import 'layout.dart';
import 'markdown.dart';

/// The five card blocks — Snippet, Overview, Context, Composite and Visual —
/// as a balanced grid or a snapping carousel of their items, sized like the
/// web renderer. A block-level `action` makes every card tappable and tells
/// the assistant which card was tapped (`Selected item: {…}`, upstream's
/// item context).
class OpenUiCardBlock extends StatelessWidget {
  const OpenUiCardBlock(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final items = el.list('items').whereType<OpenUiElement>().toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final action = el['action'] is OpenUiAction
        ? el['action'] as OpenUiAction
        : null;
    final gap = openUiGap(el['gap'], fallback: 10);
    final carousel =
        el.string('layout') == 'carousel' && el.type != 'SnippetCardBlock';
    final cards = [
      for (var i = 0; i < items.length; i++)
        OpenUiCardItemView(items[i], blockAction: action, index: i),
    ];

    if (carousel) {
      // Upstream: medium cards 20rem (17.5 in a narrow container), small
      // 17.5rem (15), overview 15rem (12.5).
      return LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth <= 480;
          final width = switch (el.type) {
            'CompositeCardBlock' || 'VisualCardBlock' => narrow ? 280.0 : 320,
            'OverviewCardBlock' => narrow ? 200.0 : 240,
            _ => narrow ? 240.0 : 280,
          };
          return OpenUiSnapRow(
            itemExtent: math.min(width.toDouble(), constraints.maxWidth * .86),
            gap: gap,
            children: cards,
          );
        },
      );
    }

    return OpenUiBalancedGrid(
      maxPerRow: switch (el.type) {
        'SnippetCardBlock' || 'CompositeCardBlock' => 2,
        _ => 3,
      },
      responsive: el.boolean('responsive', fallback: true),
      gap: gap,
      children: cards,
    );
  }
}

/// A card item rendered on its own (outside a block).
class OpenUiCardItem extends StatelessWidget {
  const OpenUiCardItem(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) => OpenUiCardItemView(el);
}

/// The first title-like text in [v].
String openUiItemTitle(Object? v) {
  if (v is OpenUiElement) {
    for (final key in const ['title', 'value', 'text', 'name', 'heading']) {
      final s = v[key];
      if (s is String && s.isNotEmpty) return s;
      if (s is OpenUiElement) {
        final nested = openUiItemTitle(s);
        if (nested.isNotEmpty) return nested;
      }
    }
    for (final value in v.props.values) {
      final nested = openUiItemTitle(
        value is OpenUiBinding ? value.value : value,
      );
      if (nested.isNotEmpty) return nested;
    }
  } else if (v is List) {
    for (final item in v) {
      final nested = openUiItemTitle(item);
      if (nested.isNotEmpty) return nested;
    }
  }
  return '';
}

/// What a tapped card tells the assistant, field for field as upstream's
/// card blocks build it (`withItemContext`); empty fields are dropped.
Map<String, Object?> openUiItemContext(OpenUiElement item, int index) {
  String? str(Object? el, String key) {
    if (el is! OpenUiElement) return null;
    final v = el[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  final id = item.string('id');
  final context = <String, Object?>{
    'itemIndex': index,
    'itemId': id,
    ...switch (item.type) {
      'SnippetCardItem' => {
        'itemTitle': str(item['lhs'], 'title') ?? str(item['lhs'], 'value'),
        'itemSubtitle': str(item['lhs'], 'subtitle'),
        'itemValue': str(item['rhs'], 'value'),
      },
      'OverviewCardItem' => {
        'itemTitle': openUiItemTitle(item['top']),
        'itemSubtitle':
            str(item['top'], 'subtitle') ?? str(item['top'], 'subtext'),
        'itemMetricValue': str(item['bottom'], 'value'),
      },
      'ContextCardItem' => {
        'itemTitle': openUiItemTitle(item['title']).isNotEmpty
            ? openUiItemTitle(item['title'])
            : item.string('title'),
        'itemBody': item.string('body'),
        'itemBgColor': item.string('bgColor'),
        'itemBgImageSrc': item.string('bgImageSrc'),
        'itemBgImageAlt': item.string('bgImageAlt'),
      },
      'CompositeCardItem' => {
        'itemHeaderTitle':
            str(item['header'], 'title') ?? str(item['header'], 'value'),
        'itemHeaderSubtitle':
            str(item['header'], 'subtitle') ?? str(item['header'], 'subtext'),
        'itemHeaderAlt': str(item['header'], 'alt'),
        'itemBodyCount': openUiFlatten(item['body']).length,
        'itemFooterPrice': switch (item['footer']) {
          final Map f => str(f['price'], 'value'),
          _ => null,
        },
        'itemFooterButtonLabel': switch (item['footer']) {
          final Map f => str(f['button'], 'label'),
          _ => null,
        },
      },
      'VisualCardItem' => {
        'itemTag': openUiItemTitle(item['tag']),
        'itemBody': str(item['body'], 'value'),
        'itemBodySubtext': str(item['body'], 'subtext'),
        'itemBgImageSrc': item.string('bgImageSrc'),
        'itemBgImageAlt': item.string('bgImageAlt'),
      },
      _ => {'itemTitle': openUiItemTitle(item)},
    },
  };
  context.removeWhere((_, v) => v == null || v == '');
  return context;
}

class OpenUiCardItemView extends StatelessWidget {
  const OpenUiCardItemView(
    this.item, {
    super.key,
    this.blockAction,
    this.index = 0,
  });

  final OpenUiElement item;
  final OpenUiAction? blockAction;

  /// Position in the block, for the item context.
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final scope = OpenUiScope.of(context);
    final action = blockAction;
    final clickable = action != null && !scope.isStreaming;
    final content = switch (item.type) {
      'SnippetCardItem' => _snippet(t, chevron: action != null),
      'OverviewCardItem' => _overview(),
      'ContextCardItem' => _context(t),
      'CompositeCardItem' => _composite(t),
      'VisualCardItem' => _visual(t),
      _ => OpenUiFallback(item),
    };
    if (action == null) return content;
    return OpenUiPressable(
      onTap: clickable
          ? () => openUiTrigger(
              context,
              action.withContext(
                'Selected item: ${jsonEncode(openUiItemContext(item, index))}',
              ),
              validate: false,
            )
          : null,
      child: content,
    );
  }

  // Upstream truncates each side of a snippet to one line.
  Widget _snippet(OpenUiThemeData t, {required bool chevron}) => OpenUiSurface(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    child: DefaultTextStyle.merge(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: Row(
        children: [
          Expanded(child: OpenUiBlock(item['lhs'])),
          if (item['rhs'] != null) ...[
            const SizedBox(width: 8),
            Flexible(child: OpenUiBlock(item['rhs'])),
          ],
          if (chevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: t.textFaint),
          ],
        ],
      ),
    ),
  );

  Widget _overview() => OpenUiSurface(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OpenUiBlock(item['top']),
        if (item['bottom'] != null) ...[
          const SizedBox(height: 10),
          OpenUiBlock(item['bottom']),
        ],
      ],
    ),
  );

  Widget _context(OpenUiThemeData t) {
    final title = item['title'];
    final body = item.string('body') ?? '';
    final image = item.string('bgImageSrc') ?? '';
    final onImage = image.isNotEmpty;
    final textColor = onImage ? Colors.white : t.textStrong;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title is OpenUiElement)
          OpenUiBlock(title)
        else if (openUiToText(title).isNotEmpty)
          Text(
            openUiToText(title),
            style: t.body(
              delta: -2,
              weight: FontWeight.w600,
              color: onImage ? Colors.white70 : t.textMuted,
            ),
          ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 8),
          OpenUiMarkdown(
            body,
            style: t.body(
              delta: -.5,
              weight: FontWeight.w600,
              color: textColor,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
    if (!onImage) {
      return OpenUiSurface(
        padding: const EdgeInsets.all(12),
        color: item.string('bgColor') == 'gray' ? t.surfaceSunk : t.primarySoft,
        child: column,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: OpenUiNetworkImage(
              src: image,
              alt: item.string('bgImageAlt'),
              radius: 0,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .25),
                    Colors.black.withValues(alpha: .75),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: column,
            ),
          ),
        ],
      ),
    );
  }

  Widget _composite(OpenUiThemeData t) {
    final footer = item['footer'];
    final price = footer is Map ? footer['price'] : null;
    final button = footer is Map ? footer['button'] : null;
    final body = openUiFlatten(item['body']);
    return OpenUiSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item['header'] != null) OpenUiBlock(item['header']),
          for (final part in body) ...[
            const SizedBox(height: 10),
            OpenUiBlock(_compact(part, body: true)),
          ],
          if (price != null || button != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, thickness: .6, color: t.border),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (price != null) OpenUiBlock(_compact(price)),
                if (button != null) OpenUiBlock(_compact(button)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Composite cards keep text, lists, tags and charts compact so every card
  /// in the block reads at the same scale (upstream
  /// `renderCompositeCardNode`).
  static Object? _compact(Object? node, {bool body = false}) {
    if (node is! OpenUiElement) return node;
    final overrides = switch (node.type) {
      'Text' || 'BoldText' when body => const {'size': 'xs'},
      'BarChart' || 'LineChart' || 'AreaChart' => const {'height': 180},
      'ListBlock' => const {'size': 'small'},
      'EntityList' => const {'size': 'small', 'header': null, 'footer': null},
      'TagBlock' => const {'size': 'sm'},
      'Button' => const {'size': 'small'},
      _ => null,
    };
    if (overrides == null) return node;
    return OpenUiElement(node.type, {...node.props, ...overrides});
  }

  Widget _visual(OpenUiThemeData t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.radius),
      child: LayoutBuilder(
        // Portrait in a grid of three; landscape when a card gets the whole
        // phone width, so it doesn't fill the screen.
        builder: (context, constraints) => AspectRatio(
          aspectRatio: constraints.maxWidth > 300 ? 4 / 3 : 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              OpenUiNetworkImage(
                src: item.string('bgImageSrc'),
                alt: item.string('bgImageAlt'),
                radius: 0,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .8),
                    ],
                  ),
                ),
              ),
              if (item['tag'] != null)
                Positioned(left: 10, top: 10, child: OpenUiBlock(item['tag'])),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: _OnImage(child: OpenUiBlock(item['body'])),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marks a subtree as drawn over a photo, so text building blocks inside it
/// switch to white.
class _OnImage extends InheritedWidget {
  const _OnImage({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_OnImage>() != null;

  @override
  bool updateShouldNotify(_OnImage old) => false;
}

// ── Building blocks ────────────────────────────────────────────────────────

/// `Text` and `BoldText`: a line with optional subtext; variant `number`
/// uses tabular figures, subtextVariant `metric` colours a leading +/-.
class OpenUiTextLine extends StatelessWidget {
  const OpenUiTextLine(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final onImage = _OnImage.of(context);
    final bold = el.type == 'BoldText';
    final delta = switch (el.string('size')) {
      'xs' => -3.0,
      'sm' => -1.5,
      'lg' => 3.0,
      _ => bold ? 0.0 : -.5,
    };
    final tabular = el.string('variant') == 'number'
        ? const [FontFeature.tabularFigures()]
        : null;
    final subtext = el.string('subtext') ?? '';
    Color subColor = onImage ? Colors.white70 : t.textMuted;
    if (el.string('subtextVariant') == 'metric') {
      if (subtext.startsWith('+')) subColor = t.success;
      if (subtext.startsWith('-')) subColor = t.danger;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OpenUiInlineMarkdown(
          el.string('value') ?? '',
          style: t
              .body(
                delta: delta,
                weight: bold ? FontWeight.w700 : FontWeight.w400,
                color: onImage ? Colors.white : (bold ? t.textStrong : t.text),
                height: 1.3,
              )
              .copyWith(fontFeatures: tabular),
        ),
        if (subtext.isNotEmpty)
          Text(
            subtext,
            style: t
                .body(delta: delta - 2, color: subColor, height: 1.3)
                .copyWith(
                  fontFeatures: el.string('subtextVariant') == 'text'
                      ? null
                      : tabular,
                ),
          ),
      ],
    );
  }
}

class OpenUiIconText extends StatelessWidget {
  const OpenUiIconText(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final variant = el.string('iconVariant') ?? 'neutral';
    final box = switch (el.string('iconSize')) {
      'xs' => 20.0,
      's' || 'sm' => 26.0,
      'l' || 'lg' => 40.0,
      'xl' => 48.0,
      _ => 32.0,
    };
    final (bg, fg) = switch (variant) {
      'info' || 'success' || 'warning' || 'danger' => (
        t.variant(variant).withValues(alpha: .15),
        t.variant(variant),
      ),
      'inverted' => (t.textStrong, t.surface),
      _ => (t.chip, t.text),
    };
    final badge = Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(box * .28),
      ),
      child: Icon(openUiIconOf(el['icon']), size: box * .52, color: fg),
    );
    final texts = _titleBlock(
      t,
      el.string('title') ?? '',
      el.string('subtitle') ?? '',
      bold: el.boolean('bold'),
      onImage: _OnImage.of(context),
    );
    if (el.string('layout') == 'vertical') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [badge, const SizedBox(height: 8), texts],
      );
    }
    return Row(
      children: [
        badge,
        const SizedBox(width: 10),
        Flexible(child: texts),
      ],
    );
  }
}

Widget _titleBlock(
  OpenUiThemeData t,
  String title,
  String subtitle, {
  required bool bold,
  bool onImage = false,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    if (title.isNotEmpty)
      Text(
        title,
        style: t.body(
          delta: -1,
          weight: bold ? FontWeight.w600 : FontWeight.w400,
          color: onImage ? Colors.white : t.textStrong,
          height: 1.3,
        ),
      ),
    if (subtitle.isNotEmpty)
      Text(
        subtitle,
        style: t.body(
          delta: -2.5,
          color: onImage ? Colors.white70 : t.textMuted,
          height: 1.3,
        ),
      ),
  ],
);

/// `ImageText` (thumbnail + title) and `ImageTextLarge` (banner + title).
class OpenUiImageText extends StatelessWidget {
  const OpenUiImageText(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final texts = _titleBlock(
      t,
      el.string('title') ?? '',
      el.string('subtitle') ?? '',
      bold: el.boolean('bold', fallback: true),
      onImage: _OnImage.of(context),
    );
    if (el.type == 'ImageTextLarge') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OpenUiNetworkImage(
            src: el.string('src'),
            alt: el.string('alt') ?? el.string('title'),
            height: 130,
            radius: t.radius - 6,
          ),
          const SizedBox(height: 10),
          texts,
        ],
      );
    }
    final vertical = el.string('layout') == 'vertical';
    final size = vertical
        ? (el.number('imageSize') ?? 40).toDouble().clamp(20.0, 120.0)
        : 40.0;
    final thumb = SizedBox(
      width: size,
      height: size,
      child: OpenUiNetworkImage(
        src: el.string('src'),
        alt: el.string('alt') ?? el.string('title'),
        height: size,
        width: size,
        radius: 8,
      ),
    );
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [thumb, const SizedBox(height: 8), texts],
      );
    }
    return Row(
      children: [
        thumb,
        const SizedBox(width: 10),
        Flexible(child: texts),
      ],
    );
  }
}

/// `MetricIndicatorInline` and `MetricIndicatorWithStrikethrough`.
class OpenUiMetric extends StatelessWidget {
  const OpenUiMetric(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final trend = el['trend'];
    Widget? trendChip;
    if (trend is Map) {
      final up = trend['direction'] != 'down';
      final color = up ? t.success : t.danger;
      final pct = openUiToNumber(trend['value']);
      trendChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${up ? '▲' : '▼'} ${pct == null ? '' : '${openUiToText(pct.abs())}%'}',
          style: t.body(
            delta: -3.5,
            weight: FontWeight.w700,
            color: color,
            height: 1.2,
          ),
        ),
      );
    }
    final value = Text(
      el.string('value') ?? '',
      style: t
          .body(
            delta: 4,
            weight: FontWeight.w700,
            color: t.textStrong,
            height: 1.2,
          )
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
    final subtext = el.string('subtext') ?? '';
    final previous = el.string('previousValue') ?? '';
    final subStyle = t.body(delta: -2.5, color: t.textMuted, height: 1.3);
    if (el.type == 'MetricIndicatorWithStrikethrough') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              value,
              if (previous.isNotEmpty)
                Text(
                  previous,
                  style: subStyle.copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: t.textMuted,
                  ),
                ),
              ?trendChip,
            ],
          ),
          if (subtext.isNotEmpty) Text(subtext, style: subStyle),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        value,
        ?trendChip,
        if (subtext.isNotEmpty) Text(subtext, style: subStyle),
      ],
    );
  }
}
