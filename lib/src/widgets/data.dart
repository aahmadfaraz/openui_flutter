import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lang.dart';
import '../theme.dart';
import '../view.dart';
import 'common.dart';
import 'forms.dart';
import 'markdown.dart';

/// `Table(columns)`: column-oriented, ten rows a page (upstream), filling
/// the width when it fits and scrolling sideways when it doesn't.
class OpenUiTable extends StatefulWidget {
  const OpenUiTable(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiTable> createState() => _OpenUiTableState();
}

class _OpenUiTableState extends State<OpenUiTable> {
  static const _pageSize = 10;
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final cols = widget.el
        .list('columns')
        .whereType<OpenUiElement>()
        .where((col) => col.type == 'Col')
        .toList();
    if (cols.isEmpty) return const SizedBox.shrink();
    final rowCount = cols
        .map((col) => col.list('data').length)
        .reduce(math.max);
    final pages = math.max(1, (rowCount / _pageSize).ceil());
    final page = math.min(_page, pages - 1);
    final start = page * _pageSize;
    final end = math.min(start + _pageSize, rowCount);

    Widget cell(Object? value, {required bool numeric, bool header = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Align(
          alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
          widthFactor: 1,
          child: value is OpenUiElement
              ? OpenUiBlock(value)
              : ConstrainedBox(
                  // Long prose wraps instead of making one endless column.
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    openUiToText(value),
                    style: t
                        .body(
                          delta: -1.5,
                          weight: header ? FontWeight.w600 : FontWeight.w400,
                          color: header ? t.textStrong : t.text,
                        )
                        .copyWith(
                          fontFeatures: numeric
                              ? const [FontFeature.tabularFigures()]
                              : null,
                        ),
                  ),
                ),
        ),
      );
    }

    final table = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radius - 2),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 0,
            ),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(color: t.border, width: .8),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: t.surfaceSunk),
                  children: [
                    for (final col in cols)
                      cell(
                        col.string('label'),
                        numeric: col.string('type') == 'number',
                        header: true,
                      ),
                  ],
                ),
                for (var r = start; r < end; r++)
                  TableRow(
                    children: [
                      for (final col in cols)
                        cell(
                          r < col.list('data').length
                              ? col.list('data')[r]
                              : null,
                          numeric: col.string('type') == 'number',
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (pages == 1) return table;

    Widget arrow(IconData icon, int? to) => IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      color: t.text,
      disabledColor: t.textFaint,
      onPressed: to == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _page = to);
            },
      icon: Icon(icon),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        table,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            arrow(Icons.chevron_left_rounded, page > 0 ? page - 1 : null),
            Text(
              '${page + 1} / $pages',
              style: t
                  .body(delta: -2, color: t.textMuted)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            arrow(
              Icons.chevron_right_rounded,
              page < pages - 1 ? page + 1 : null,
            ),
          ],
        ),
      ],
    );
  }
}

class OpenUiEntityList extends StatelessWidget {
  const OpenUiEntityList(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final small = el.string('size') == 'small';
    final header = small ? null : el['header'];
    final footer = small ? null : el['footer'];
    final rows = el.list('rows').whereType<Map>().toList();

    Widget row(Map r, {bool isHeader = false, bool isFooter = false}) {
      final numeric = r['rightVariant'] == 'number';
      final weight = isHeader || isFooter ? FontWeight.w600 : FontWeight.w400;
      final color = isHeader ? t.textMuted : (isFooter ? t.textStrong : t.text);
      final style = t.body(
        delta: small ? -2 : -1,
        weight: weight,
        color: color,
      );
      return Container(
        padding: EdgeInsets.symmetric(vertical: small ? 5 : 9),
        decoration: BoxDecoration(
          border: isFooter
              ? Border(top: BorderSide(color: t.borderStrong, width: 1.2))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Both sides wrap; a long value takes up to ~60% of the row.
            Expanded(
              flex: 2,
              child: OpenUiInlineMarkdown(
                openUiToText(r['left']),
                style: style,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 3,
              child: OpenUiInlineMarkdown(
                openUiToText(r['right']),
                textAlign: TextAlign.right,
                style: style.copyWith(
                  fontFeatures: numeric
                      ? const [FontFeature.tabularFigures()]
                      : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header is Map) row(header, isHeader: true),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0 || header is Map)
            Divider(height: 1, thickness: .6, color: t.border),
          row(rows[i]),
        ],
        if (footer is Map) row(footer, isFooter: true),
      ],
    );
  }
}

class OpenUiTagBlock extends StatelessWidget {
  const OpenUiTagBlock(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in el.list('tags'))
          tag is OpenUiElement
              ? OpenUiBlock(tag)
              : OpenUiTag(text: openUiToText(tag), size: el.string('size')),
      ],
    );
  }
}

class OpenUiTagComponent extends StatelessWidget {
  const OpenUiTagComponent(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) => OpenUiTag(
    text: el.string('text') ?? '',
    size: el.string('size'),
    variant: el.string('variant'),
    icon: openUiIconOf(el['icon']),
  );
}

/// A bare `Icon(name, category)`.
class OpenUiIconComponent extends StatelessWidget {
  const OpenUiIconComponent(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    return Icon(openUiIconOf(el), size: t.baseFontSize + 3, color: t.text);
  }
}

class OpenUiListBlock extends StatelessWidget {
  const OpenUiListBlock(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final scope = OpenUiScope.of(context);
    final items = el.list('items').whereType<OpenUiElement>().toList();
    final variant = el.string('variant') ?? 'number';
    final small = el.string('size') == 'small';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: .6, color: t.border),
          Builder(
            builder: (context) {
              final item = items[i];
              final image = item['image'];
              final raw = item['action'];
              final title = item.string('title') ?? '';
              // Any action that isn't an Action() sends the item's title.
              final action = raw is OpenUiAction
                  ? raw
                  : raw == null || raw == false
                  ? null
                  : OpenUiAction.toAssistant(title);
              final subtitle = item.string('subtitle') ?? '';
              final actionLabel = item.string('actionLabel') ?? '';
              final Widget? leading = variant == 'image' && image is Map
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: OpenUiNetworkImage(
                        src: openUiToText(image['src']),
                        alt: openUiToText(image['alt']),
                        height: 40,
                        radius: 8,
                      ),
                    )
                  : variant == 'number'
                  ? Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.chip,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: t.body(
                          delta: -3,
                          weight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    )
                  : null;
              return InkWell(
                onTap: action != null && !scope.isStreaming
                    ? () => openUiTrigger(context, action, validate: false)
                    : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: small ? 7 : 10),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading,
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: t.body(
                                delta: small ? -1.5 : -.5,
                                weight: FontWeight.w500,
                                color: t.textStrong,
                              ),
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                style: t.body(delta: -2, color: t.textMuted),
                              ),
                          ],
                        ),
                      ),
                      if (action != null) ...[
                        if (actionLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            actionLabel,
                            style: t.body(
                              delta: -2,
                              weight: FontWeight.w600,
                              color: t.primary,
                            ),
                          ),
                        ],
                        Icon(
                          Icons.chevron_right_rounded,
                          color: t.textFaint,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class OpenUiButtons extends StatelessWidget {
  const OpenUiButtons(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final buttons = openUiFlatten(el['buttons']);
    if (el.string('direction') == 'column') {
      return OpenUiColumn(buttons, gap: 8);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final b in buttons) OpenUiBlock(b)],
    );
  }
}

/// Runs a button's action from its place in the tree: inside a `Form` the
/// form's values ride along (and must validate first).
void openUiTrigger(
  BuildContext context,
  OpenUiAction action, {
  bool validate = true,
}) {
  HapticFeedback.lightImpact();
  OpenUiScope.of(context).runAction(
    action,
    form: OpenUiFormScope.maybeOf(context),
    validate: validate,
  );
}

class OpenUiButton extends StatelessWidget {
  const OpenUiButton(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final scope = OpenUiScope.of(context);
    final label = el.string('label') ?? '';
    final variant = el.string('variant') ?? 'primary';
    final destructive = el.string('type') == 'destructive';
    final accent = destructive ? t.danger : t.primary;
    final (hPad, vPad, delta) = switch (el.string('size')) {
      'extra-small' => (10.0, 5.0, -3.0),
      'small' => (12.0, 7.0, -2.0),
      'large' => (20.0, 12.0, .5),
      _ => (16.0, 9.0, -1.0),
    };
    // A Button without an action sends its label to the assistant.
    final raw = el['action'];
    final action = raw is OpenUiAction ? raw : OpenUiAction.toAssistant(label);
    final enabled = !scope.isStreaming;
    final (bg, fg, border) = switch (variant) {
      'secondary' => (
        Colors.transparent,
        destructive ? t.danger : t.textStrong,
        t.borderStrong,
      ),
      'tertiary' => (Colors.transparent, accent, Colors.transparent),
      _ => (accent, destructive ? Colors.white : t.onPrimary, accent),
    };
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () => openUiTrigger(
                  context,
                  action,
                  validate: variant == 'primary',
                )
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Text(
              label,
              style: t.body(
                delta: delta,
                weight: FontWeight.w600,
                color: fg,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OpenUiIconButton extends StatelessWidget {
  const OpenUiIconButton(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final scope = OpenUiScope.of(context);
    final name = el.string('name') ?? '';
    final raw = el['action'];
    final action = raw is OpenUiAction ? raw : OpenUiAction.toAssistant(name);
    final size = switch (el.string('size')) {
      'extra-small' => 26.0,
      'small' => 32.0,
      'large' => 48.0,
      _ => 40.0,
    };
    final (bg, fg, border) = switch (el.string('variant') ?? 'secondary') {
      'primary' => (t.primary, t.onPrimary, t.primary),
      'tertiary' => (Colors.transparent, t.primary, Colors.transparent),
      _ => (Colors.transparent, t.textStrong, t.borderStrong),
    };
    final circle = el.string('shape') == 'circle';
    return Tooltip(
      message: name,
      child: Opacity(
        opacity: scope.isStreaming ? .5 : 1,
        child: Material(
          color: bg,
          shape: circle
              ? CircleBorder(side: BorderSide(color: border))
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: border),
                ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: scope.isStreaming
                ? null
                : () => openUiTrigger(context, action, validate: false),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                openUiIconOf(el['icon']),
                size: size * .45,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `FollowUpBlock([FollowUpItem(text)…])`: "Related Queries" — suggested
/// next questions; tapping one sends its text once the answer has landed.
class OpenUiFollowUps extends StatelessWidget {
  const OpenUiFollowUps(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final scope = OpenUiScope.of(context);
    final items = el.list('items').whereType<OpenUiElement>().toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            'Related Queries',
            style: t.body(
              delta: -1.5,
              weight: FontWeight.w600,
              color: t.textMuted,
            ),
          ),
        ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: .6, color: t.border),
          InkWell(
            onTap: scope.isStreaming
                ? null
                : () => openUiTrigger(
                    context,
                    OpenUiAction.toAssistant(items[i].string('text') ?? ''),
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 16,
                    color: t.textFaint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      items[i].string('text') ?? '',
                      style: t.body(delta: -1, color: t.text),
                    ),
                  ),
                  Icon(Icons.add_rounded, size: 18, color: t.textFaint),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
