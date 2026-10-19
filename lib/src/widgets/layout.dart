import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lang.dart';
import '../theme.dart';
import '../view.dart';
import 'common.dart';
import 'markdown.dart';

/// `Stack` — and the flex half of `Card`, which takes the same params after
/// its variant. Columns stretch; a row of inline items (buttons, tags)
/// wraps; a row of blocks (cards, charts) becomes a grid with as many
/// columns as fit at a readable width, so a phone stacks them and a tablet
/// doesn't.
class OpenUiFlex extends StatelessWidget {
  const OpenUiFlex(this.el, {super.key, this.minColumnWidth = 300});

  final OpenUiElement el;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) {
    final gap = openUiGap(el['gap']);
    if (el.string('direction') != 'row') {
      final slots = openUiSlots(el['children']);
      if (slots.isEmpty) return const SizedBox.shrink();
      return OpenUiColumn(
        slots,
        gap: gap,
        cross: switch (el.string('align')) {
          'start' => CrossAxisAlignment.start,
          'center' => CrossAxisAlignment.center,
          'end' => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.stretch,
        },
      );
    }

    final children = openUiFlatten(el['children']);
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.every((c) => openUiIsInline(context, c))) {
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: switch (el.string('justify')) {
          'center' => WrapAlignment.center,
          'end' => WrapAlignment.end,
          'between' => WrapAlignment.spaceBetween,
          'around' => WrapAlignment.spaceAround,
          'evenly' => WrapAlignment.spaceEvenly,
          _ => WrapAlignment.start,
        },
        children: [for (final c in children) OpenUiBlock(c)],
      );
    }
    return OpenUiGrid(children, gap: gap, minColumnWidth: minColumnWidth);
  }
}

/// Blocks in as many equal columns as fit at [minColumnWidth].
class OpenUiGrid extends StatelessWidget {
  const OpenUiGrid(
    this.children, {
    super.key,
    this.gap = 12,
    this.minColumnWidth = 300,
    this.maxColumns,
  });

  final List<Object?> children;
  final double gap;
  final double minColumnWidth;
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var cols = width.isFinite
            ? ((width + gap) / (minColumnWidth + gap)).floor()
            : 1;
        cols = cols.clamp(1, math.min(children.length, maxColumns ?? 99));
        if (cols == 1) return OpenUiColumn(children, gap: gap);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i += cols) ...[
              if (i > 0) SizedBox(height: gap),
              // Not IntrinsicHeight: charts measure with LayoutBuilder,
              // which can't report intrinsic sizes.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) SizedBox(width: gap),
                    Expanded(
                      child: i + j < children.length
                          ? OpenUiBlock(children[i + j])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class OpenUiCard extends StatelessWidget {
  const OpenUiCard(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    return OpenUiSurface(variant: el.string('variant'), child: OpenUiFlex(el));
  }
}

class OpenUiSeparator extends StatelessWidget {
  const OpenUiSeparator(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final color = OpenUiTheme.of(context).border;
    if (el.string('orientation') == 'vertical') {
      return SizedBox(
        height: 24,
        child: VerticalDivider(width: 1, thickness: 1, color: color),
      );
    }
    return Divider(height: 1, thickness: 1, color: color);
  }
}

class OpenUiSteps extends StatelessWidget {
  const OpenUiSteps(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final items = el.list('items').whereType<OpenUiElement>().toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.primarySoft,
                        border: Border.all(color: t.primaryBorder),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: t.body(
                          delta: -3,
                          weight: FontWeight.w700,
                          color: t.primaryText,
                          height: 1,
                        ),
                      ),
                    ),
                    if (i < items.length - 1)
                      Expanded(child: Container(width: 1.5, color: t.border)),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 1,
                      bottom: i < items.length - 1 ? 14 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].string('title') ?? '',
                          style: t.body(
                            delta: -.5,
                            weight: FontWeight.w600,
                            color: t.textStrong,
                          ),
                        ),
                        if ((items[i].string('details') ?? '').isNotEmpty)
                          OpenUiMarkdown(
                            items[i].string('details')!,
                            style: t.body(delta: -1.5, color: t.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// `Tabs([TabItem(value, trigger, content)…])`. Opens the first tab; while
/// the answer streams it follows whichever tab is filling in, until the user
/// picks one (upstream `Tabs`).
class OpenUiTabs extends StatefulWidget {
  const OpenUiTabs(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiTabs> createState() => _OpenUiTabsState();
}

class _OpenUiTabsState extends State<OpenUiTabs> {
  var _index = 0;
  var _userPicked = false;
  final _sizes = <int, int>{};

  @override
  Widget build(BuildContext context) {
    final items = widget.el.list('items').whereType<OpenUiElement>().toList();
    if (items.isEmpty) return const SizedBox.shrink();
    if (OpenUiScope.of(context).isStreaming && !_userPicked) {
      for (var i = 0; i < items.length; i++) {
        final size = items[i].toString().length;
        if ((_sizes[i] ?? -1) < size) _index = i;
        _sizes[i] = size;
      }
    }
    final index = _index.clamp(0, items.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: OpenUiPill(
                    label: items[i].string('trigger') ?? '',
                    selected: i == index,
                    onTap: () => setState(() {
                      _index = i;
                      _userPicked = true;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          layoutBuilder: (current, previous) => current ?? const SizedBox(),
          child: KeyedSubtree(
            key: ValueKey(index),
            child: OpenUiBlock(items[index]['content']),
          ),
        ),
      ],
    );
  }
}

/// A selectable pill (tab triggers, chips).
class OpenUiPill extends StatelessWidget {
  const OpenUiPill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.showCheck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Chips: a tick appears while selected (not for tab triggers).
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final color = selected ? t.primaryText : t.textMuted;
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? t.primarySoft : t.chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? t.primaryBorder : t.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
            ] else if (showCheck)
              // A selected chip gains a tick, so picks read at a glance.
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: color,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            Flexible(
              child: Text(
                label,
                style: t.body(
                  delta: -2,
                  weight: FontWeight.w600,
                  color: color,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `Accordion([AccordionItem(value, trigger, content)…])`: one item open at
/// a time; while the answer streams the newest item opens, until the user
/// takes over (upstream `Accordion`).
class OpenUiAccordion extends StatefulWidget {
  const OpenUiAccordion(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiAccordion> createState() => _OpenUiAccordionState();
}

class _OpenUiAccordionState extends State<OpenUiAccordion> {
  int? _open;
  var _userTouched = false;
  var _seen = 0;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final items = widget.el.list('items').whereType<OpenUiElement>().toList();
    if (OpenUiScope.of(context).isStreaming && !_userTouched) {
      if (items.length > _seen) _open = items.length - 1;
    }
    _seen = items.length;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radius - 2),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: .6, color: t.border),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _userTouched = true;
                  _open = _open == i ? null : i;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].string('trigger') ?? '',
                        style: t.body(
                          delta: -.5,
                          weight: FontWeight.w600,
                          color: t.textStrong,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open == i ? .5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: t.textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open == i
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: OpenUiBlock(items[i]['content']),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

/// `Carousel([[slide1…], [slide2…]], variant)`: fixed-width slides (280px,
/// 248px on narrow screens) that snap into place, with edge fades hinting
/// at more (upstream `Carousel`).
class OpenUiCarousel extends StatelessWidget {
  const OpenUiCarousel(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final slides = el.list('children').where((s) => s != null).toList();
    if (slides.isEmpty) return const SizedBox.shrink();
    final variant = el.string('variant') ?? 'card';
    final width = MediaQuery.sizeOf(context).width <= 400 ? 248.0 : 280.0;
    return OpenUiSnapRow(
      itemExtent: width,
      gap: 10,
      children: [
        for (final slide in slides)
          OpenUiSurface(
            variant: variant,
            child: OpenUiColumn(openUiFlatten(slide), gap: 10),
          ),
      ],
    );
  }
}

/// A horizontal row of [itemExtent]-wide children that snaps to item
/// starts, with soft fades at the edges while there's more to scroll.
class OpenUiSnapRow extends StatefulWidget {
  const OpenUiSnapRow({
    super.key,
    required this.children,
    required this.itemExtent,
    this.gap = 10,
  });

  final List<Widget> children;
  final double itemExtent;
  final double gap;

  @override
  State<OpenUiSnapRow> createState() => _OpenUiSnapRowState();
}

class _OpenUiSnapRowState extends State<OpenUiSnapRow> {
  final _controller = ScrollController();
  var _atStart = true;
  var _atEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_edges);
    WidgetsBinding.instance.addPostFrameCallback((_) => _edges());
  }

  void _edges() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final atStart = p.pixels <= p.minScrollExtent + 1;
    final atEnd = p.pixels >= p.maxScrollExtent - 1;
    if (atStart != _atStart || atEnd != _atEnd) {
      setState(() {
        _atStart = atStart;
        _atEnd = atEnd;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: _SnapPhysics(extent: widget.itemExtent + widget.gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.children.length; i++) ...[
            if (i > 0) SizedBox(width: widget.gap),
            SizedBox(width: widget.itemExtent, child: widget.children[i]),
          ],
        ],
      ),
    );
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          _atStart ? Colors.black : Colors.transparent,
          Colors.black,
          Colors.black,
          _atEnd ? Colors.black : Colors.transparent,
        ],
        stops: const [0, .06, .94, 1],
      ).createShader(bounds),
      child: row,
    );
  }
}

/// Snaps a fling or drag to the nearest multiple of [extent].
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.extent, super.parent});

  final double extent;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tol = toleranceFor(position);
    var page = position.pixels / extent;
    if (velocity < -tol.velocity) {
      page -= .5;
    } else if (velocity > tol.velocity) {
      page += .5;
    }
    final target = (page.roundToDouble() * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tol.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tol,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// `Modal(title, $open, children, size)`. Bound to a `$boolean`, it opens
/// as a dialog while the state is true and writes false when dismissed; its
/// content stays live (re-parses, `$state`, streaming) while open. Without a
/// binding, an open modal renders inline as a card — a chat-friendly
/// stand-in for a dialog nobody can close.
class OpenUiModal extends StatefulWidget {
  const OpenUiModal(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiModal> createState() => _OpenUiModalState();
}

class _OpenUiModalState extends State<OpenUiModal> {
  bool _showing = false;
  ValueNotifier<(OpenUiElement, OpenUiScope)>? _live;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OpenUiModal old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _live?.dispose();
    super.dispose();
  }

  void _sync() {
    final scope = OpenUiScope.of(context);
    final live = _live;
    if (live == null) {
      _live = ValueNotifier((widget.el, scope));
    } else {
      // After this frame: the dialog rebuilds from the latest props.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) live.value = (widget.el, scope);
      });
    }
    final binding = widget.el.binding('open');
    if (binding == null) return;
    final open = openUiTruthy(binding.value);
    if (open && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(binding.name));
    } else if (!open && _showing) {
      _showing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  Future<void> _show(String stateName) async {
    if (!mounted) return;
    final theme = OpenUiTheme.of(context);
    final setVar = OpenUiScope.of(context).setVar;
    final live = _live!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ValueListenableBuilder(
        valueListenable: live,
        builder: (context, value, _) {
          final (el, scope) = value;
          final maxWidth = switch (el.string('size')) {
            'sm' => 380.0,
            'lg' => 720.0,
            _ => 520.0,
          };
          return OpenUiTheme(
            data: theme,
            child: OpenUiScope(
              library: scope.library,
              isStreaming: scope.isStreaming,
              runAction: scope.runAction,
              setVar: scope.setVar,
              readVar: scope.readVar,
              form: scope.form,
              stateVersion: scope.stateVersion,
              child: Dialog(
                backgroundColor: theme.surfaceRaised,
                insetPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.radius + 2),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 10, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                el.string('title') ?? '',
                                style: theme.body(
                                  delta: 2,
                                  weight: FontWeight.w700,
                                  color: theme.textStrong,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: theme.textMuted,
                              ),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OpenUiColumn(openUiFlatten(el['children'])),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    _showing = false;
    setVar(stateName, false);
  }

  @override
  Widget build(BuildContext context) {
    final el = widget.el;
    if (el.binding('open') != null || !openUiTruthy(el['open'])) {
      return const SizedBox.shrink();
    }
    final t = OpenUiTheme.of(context);
    return OpenUiSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            el.string('title') ?? '',
            style: t.body(
              delta: 1,
              weight: FontWeight.w700,
              color: t.textStrong,
            ),
          ),
          const SizedBox(height: 10),
          OpenUiColumn(openUiFlatten(el['children'])),
        ],
      ),
    );
  }
}

/// `SectionBlock(sections, isFoldable)` with `SectionItem(value, trigger,
/// content)`: titled sections, open as they stream in; foldable unless
/// `isFoldable` is false.
class OpenUiSectionBlock extends StatefulWidget {
  const OpenUiSectionBlock(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiSectionBlock> createState() => _OpenUiSectionBlockState();
}

// Upstream: while streaming, each new section opens (they accumulate); when
// the answer lands, only the first stays open unless the user took over. A
// finished answer opens with the first section only.
class _OpenUiSectionBlockState extends State<OpenUiSectionBlock> {
  final _open = <int>{};
  var _userTouched = false;
  var _seen = 0;
  bool? _wasStreaming;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final sections = widget.el
        .list('sections')
        .whereType<OpenUiElement>()
        .toList();
    final foldable = widget.el.boolean('isFoldable', fallback: true);
    final streaming = OpenUiScope.of(context).isStreaming;
    if (!_userTouched) {
      if (streaming) {
        for (var i = _seen; i < sections.length; i++) {
          _open.add(i);
        }
      } else if (_wasStreaming != false) {
        _open
          ..clear()
          ..add(0);
      }
    }
    _seen = sections.length;
    _wasStreaming = streaming;
    final closed = {
      for (var i = 0; i < sections.length; i++)
        if (foldable && !_open.contains(i)) i,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) Divider(height: 20, thickness: .6, color: t.border),
          InkWell(
            onTap: foldable
                ? () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _userTouched = true;
                      _open.contains(i) ? _open.remove(i) : _open.add(i);
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sections[i].string('trigger') ?? '',
                      style: t.body(
                        delta: .5,
                        weight: FontWeight.w600,
                        color: t.textStrong,
                      ),
                    ),
                  ),
                  if (foldable)
                    AnimatedRotation(
                      turns: closed.contains(i) ? 0 : .5,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: t.textMuted,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: closed.contains(i)
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OpenUiBlock(sections[i]['content']),
                  ),
          ),
        ],
      ],
    );
  }
}
