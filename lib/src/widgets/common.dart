import 'package:flutter/material.dart';

import '../icons/icons.dart';
import '../lang.dart';
import '../library.dart';
import '../theme.dart';
import '../view.dart';
import 'markdown.dart';

/// Renders any evaluated openui-lang value: a component (through the
/// view's library), a list of them, or a bare literal. A component the
/// library can't render degrades to its nested components and text (see
/// [OpenUiFallback]) rather than leaving a hole.
class OpenUiBlock extends StatefulWidget {
  const OpenUiBlock(this.value, {super.key});

  final Object? value;

  @override
  State<OpenUiBlock> createState() => _OpenUiBlockState();
}

/// The program is re-parsed on every streamed chunk, so every component
/// gets a fresh (but usually identical) value. Handing Flutter back the very
/// same widget when nothing changed lets it skip the whole subtree — charts,
/// tables and images stay put while only the growing tail rebuilds.
class _OpenUiBlockState extends State<OpenUiBlock> {
  Object? _value;
  Widget? _built;
  bool? _streaming;
  OpenUiLibrary? _library;
  int? _version;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme, media or scope changed: builders may have read them through
    // this context, so the cached widget can't be trusted.
    _built = null;
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final scope = OpenUiScope.of(context);
    final cached = _built;
    if (cached != null &&
        _streaming == scope.isStreaming &&
        identical(_library, scope.library) &&
        _version == scope.stateVersion &&
        openUiSame(_value, v)) {
      return cached;
    }
    _value = v;
    _streaming = scope.isStreaming;
    _library = scope.library;
    _version = scope.stateVersion;
    return _built = _build(context, v, scope);
  }

  static Widget _build(BuildContext context, Object? v, OpenUiScope scope) {
    if (v is OpenUiElement) {
      final builder = scope.library.components[v.type]?.builder;
      return OpenUiAppear(
        animate: scope.isStreaming,
        child: builder != null ? builder(context, v) : OpenUiFallback(v),
      );
    }
    if (v is List) return OpenUiColumn(openUiFlatten(v), gap: 12);
    if (v == null || v is OpenUiAction || v is Map) {
      return const SizedBox.shrink();
    }
    return Text(openUiToText(v), style: OpenUiTheme.of(context).body());
  }
}

/// Nested lists flattened; nulls (unresolved refs, `cond ? x : null`) dropped.
List<Object?> openUiFlatten(Object? v) {
  if (v == null) return const [];
  if (v is! List) return [v];
  return [for (final item in v) ...openUiFlatten(item)];
}

/// The `gap` names Stack, Card and card blocks take, in logical pixels.
double openUiGap(Object? name, {double fallback = 12}) {
  if (name is num) return name.toDouble();
  return switch (name) {
    'none' => 0,
    'xs' => 4,
    's' => 8,
    'm' => 12,
    'l' => 16,
    'xl' => 24,
    '2xl' => 32,
    _ => fallback,
  };
}

/// Whether [value] renders inline (button, tag…) rather than as a block.
bool openUiIsInline(BuildContext context, Object? value) {
  if (value is! OpenUiElement) return true;
  return OpenUiScope.of(context).library.components[value.type]?.inline ??
      false;
}

/// A column of openui values separated by [gap].
class OpenUiColumn extends StatelessWidget {
  const OpenUiColumn(
    this.children, {
    super.key,
    this.gap = 12,
    this.cross = CrossAxisAlignment.stretch,
  });

  final List<Object?> children;
  final double gap;
  final CrossAxisAlignment cross;

  @override
  Widget build(BuildContext context) {
    // Always a Column, one slot per child, even for a single child or a
    // child whose statement hasn't streamed in yet (null): each component
    // keeps its element — and its state and entrance animation — as its
    // siblings arrive, instead of being remounted when the list grows.
    final slots = <Widget>[];
    var seen = false;
    for (final child in children) {
      slots.add(
        Padding(
          padding: EdgeInsets.only(top: child != null && seen ? gap : 0),
          child: OpenUiBlock(child),
        ),
      );
      if (child != null) seen = true;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: slots,
    );
  }
}

/// A container's children as stable slots: nested lists flattened, but a
/// child not evaluated yet (an unresolved reference mid-stream) kept as a
/// null placeholder so later siblings don't shift position when it lands.
List<Object?> openUiSlots(Object? v) {
  if (v == null) return const [];
  if (v is! List) return [v];
  return [
    for (final item in v)
      if (item is List) ...openUiFlatten(item) else item,
  ];
}

/// A rounded card surface: `card` (default), `sunk` or `clear`.
class OpenUiSurface extends StatelessWidget {
  const OpenUiSurface({
    super.key,
    required this.child,
    this.variant,
    this.padding = const EdgeInsets.all(14),
    this.color,
  });

  final Widget child;
  final String? variant;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    if (variant == 'clear') return child;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (variant == 'sunk' ? t.surfaceSunk : t.surface),
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.border),
      ),
      child: child,
    );
  }
}

/// A pill badge in a variant colour (`neutral`, `info`, `success`,
/// `warning`, `danger`).
class OpenUiTag extends StatelessWidget {
  const OpenUiTag({
    super.key,
    required this.text,
    this.size,
    this.variant,
    this.icon,
  });

  final String text;
  final String? size;
  final String? variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final neutral = variant == null || variant == 'neutral';
    final color = neutral ? t.text : t.variant(variant);
    final delta = switch (size) {
      'sm' => -3.5,
      'lg' => -1.0,
      _ => -2.5,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: neutral ? t.chip : color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: neutral ? t.chipBorder : color.withValues(alpha: .3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: t.baseFontSize + delta, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: t.body(
                delta: delta,
                weight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The IconData of an `Icon(name, category)` element (or null).
IconData? openUiIconOf(Object? icon) {
  if (icon is! OpenUiElement || icon.type != 'Icon') return null;
  return openUiIcon(icon.string('name'), category: icon.string('category'));
}

/// A network image through the theme's [OpenUiThemeData.imageBuilder], with
/// an alt-text placeholder while loading, on error, or without a URL.
class OpenUiNetworkImage extends StatelessWidget {
  const OpenUiNetworkImage({
    super.key,
    this.src,
    this.alt,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.radius,
  });

  final String? src;
  final String? alt;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Alignment alignment;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final placeholder = Container(
      height: height,
      width: width ?? double.infinity,
      color: t.skeleton,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: (alt ?? '').isEmpty || (height ?? 100) < 60
          ? Icon(Icons.image_outlined, color: t.textFaint, size: 20)
          : Text(
              alt!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: t.body(delta: -2.5, color: t.textFaint),
            ),
    );
    final url = src ?? '';
    Widget image;
    if (url.isEmpty) {
      image = placeholder;
    } else if (t.imageBuilder != null) {
      image = t.imageBuilder!(
        context,
        url,
        fit: fit,
        width: width ?? double.infinity,
        height: height,
        alignment: alignment,
        placeholder: placeholder,
      );
    } else {
      image = Image.network(
        url,
        fit: fit,
        width: width ?? double.infinity,
        height: height,
        alignment: alignment,
        semanticLabel: alt,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? t.radius - 4),
      child: image,
    );
  }
}

/// A component with no renderer: show what it nests — child components and
/// its text props — so the answer degrades to readable content. `…Item`s
/// get a card surface so a block of them still reads as cards.
class OpenUiFallback extends StatelessWidget {
  const OpenUiFallback(this.element, {super.key});

  final OpenUiElement element;

  static const _textProps = {
    'title',
    'heading',
    'name',
    'text',
    'value',
    'label',
    'trigger',
    'subtitle',
    'subtext',
    'description',
    'body',
    'details',
  };
  static const _primary = {'title', 'heading', 'name', 'value', 'trigger'};

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final parts = <Widget>[];
    void collect(String? key, Object? v) {
      if (v is OpenUiElement) {
        parts.add(OpenUiBlock(v));
      } else if (v is List) {
        for (final item in v) {
          collect(null, item);
        }
      } else if (v is Map) {
        for (final e in v.entries) {
          collect(e.key.toString(), e.value);
        }
      } else if (v is String && v.isNotEmpty && _textProps.contains(key)) {
        final primary = _primary.contains(key);
        parts.add(
          OpenUiMarkdown(
            v,
            style: t.body(
              delta: primary ? -.5 : -1.5,
              weight: primary ? FontWeight.w600 : FontWeight.w400,
              color: primary ? t.textStrong : t.textMuted,
            ),
          ),
        );
      }
    }

    element.props.forEach(
      (key, value) =>
          collect(key, value is OpenUiBinding ? value.value : value),
    );
    if (parts.isEmpty) return const SizedBox.shrink();
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          parts[i],
        ],
      ],
    );
    return element.type.endsWith('Item')
        ? OpenUiSurface(child: column)
        : column;
  }
}

/// Text for a field value in a submission: lists joined, checked keys of a
/// `{name: bool}` map, dates as yyyy-mm-dd.
String openUiFieldText(Object? v) {
  if (v is DateTimeRange) {
    return '${openUiFieldText(v.start)} to ${openUiFieldText(v.end)}';
  }
  if (v is DateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${v.year}-${two(v.month)}-${two(v.day)}';
  }
  if (v is Map) {
    final on = [
      for (final e in v.entries)
        if (e.value == true) e.key.toString(),
    ];
    return on.join(', ');
  }
  if (v is List) return v.map(openUiFieldText).join(', ');
  return openUiToText(v);
}

/// Eases a component in (fade + short rise) when it first appears while the
/// answer streams, so the UI fills in instead of popping. Components already
/// on screen keep their state and don't replay it; a finished answer (e.g.
/// from history) shows at once.
class OpenUiAppear extends StatefulWidget {
  const OpenUiAppear({super.key, required this.child, this.animate = true});

  final Widget child;

  /// Only read when first mounted.
  final bool animate;

  @override
  State<OpenUiAppear> createState() => _OpenUiAppearState();
}

class _OpenUiAppearState extends State<OpenUiAppear> {
  late final bool _animate = widget.animate;

  @override
  Widget build(BuildContext context) {
    if (!_animate) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: widget.child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

/// Row sizes for [count] items at [width], following upstream
/// `CardBlockLayout`: one column at ≤480px, two at ≤768px (an odd last
/// item spans the row), else balanced rows of at most [maxPerRow]
/// (5 → 3+2, 7 → 3+2+2). [responsive] false keeps [maxPerRow] everywhere.
List<int> openUiRowSizes(
  int count,
  double width, {
  required int maxPerRow,
  bool responsive = true,
}) {
  if (count <= 0) return const [];
  var perRow = maxPerRow;
  if (responsive && width <= 480) perRow = 1;
  if (responsive && width > 480 && width <= 768) perRow = 2;
  perRow = perRow.clamp(1, count);
  if (perRow <= 2) {
    return [
      for (var i = 0; i < count; i += perRow) (count - i).clamp(1, perRow),
    ];
  }
  final rows = (count / perRow).ceil();
  final base = count ~/ rows;
  final extra = count % rows;
  return [for (var r = 0; r < rows; r++) base + (r < extra ? 1 : 0)];
}

/// [children] laid out in [openUiRowSizes] rows; cells in a row share its
/// width.
class OpenUiBalancedGrid extends StatelessWidget {
  const OpenUiBalancedGrid({
    super.key,
    required this.children,
    required this.maxPerRow,
    this.responsive = true,
    this.gap = 10,
  });

  final List<Widget> children;
  final int maxPerRow;
  final bool responsive;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizes = openUiRowSizes(
          children.length,
          constraints.maxWidth,
          maxPerRow: maxPerRow,
          responsive: responsive,
        );
        var i = 0;
        final rows = <Widget>[];
        for (final size in sizes) {
          final cells = children.sublist(i, i + size);
          i += size;
          rows.add(
            size == 1
                ? cells.single
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var j = 0; j < cells.length; j++) ...[
                        if (j > 0) SizedBox(width: gap),
                        Expanded(child: cells[j]),
                      ],
                    ],
                  ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: gap),
              rows[r],
            ],
          ],
        );
      },
    );
  }
}

/// A tappable card: dips slightly while pressed so the tap reads as a press
/// even without an ink splash. Disabled (no dip) when [onTap] is null.
class OpenUiPressable extends StatefulWidget {
  const OpenUiPressable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<OpenUiPressable> createState() => _OpenUiPressableState();
}

class _OpenUiPressableState extends State<OpenUiPressable> {
  var _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
