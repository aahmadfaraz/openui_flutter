import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../lang.dart';
import '../theme.dart';

/// 1250 → "1.3k", 2400000 → "2.4M"; whole numbers stay whole.
String _compact(num v) {
  final a = v.abs();
  String trim(double x) => x.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  if (a >= 1e9) return '${trim(v / 1e9)}B';
  if (a >= 1e6) return '${trim(v / 1e6)}M';
  if (a >= 1e4) return '${trim(v / 1e3)}k';
  return openUiToText(v is double ? double.parse(v.toStringAsFixed(2)) : v);
}

typedef _Slice = ({String label, num value, Color color});
typedef _Series = ({String name, List<num> values});

/// Every chart: the 1D ones (Pie, Radial, SingleStackedBar) take `labels` +
/// `values`; the 2D ones take `labels` + `Series(...)`; Scatter takes
/// `ScatterSeries(name, [Point(x, y)…])`.
class OpenUiChart extends StatelessWidget {
  const OpenUiChart(this.el, {super.key});

  final OpenUiElement el;

  List<num> _numbers(Object? v) => v is List
      ? v.map((x) => openUiToNumber(x) ?? 0).toList(growable: false)
      : const [];

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final labels = el.list('labels').map(openUiToText).toList(growable: false);
    final axisStyle = t.body(delta: -3.5, color: t.textFaint);

    Widget withAxes(Widget chart, {Widget? legend}) {
      final xLabel = el.string('xLabel') ?? '';
      final yLabel = el.string('yLabel') ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (yLabel.isNotEmpty) ...[
            Text(yLabel, style: axisStyle),
            const SizedBox(height: 6),
          ],
          chart,
          if (xLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(xLabel, style: axisStyle, textAlign: TextAlign.center),
          ],
          if (legend != null) ...[const SizedBox(height: 10), legend],
        ],
      );
    }

    switch (el.type) {
      case 'PieChart':
      case 'RadialChart':
      case 'SingleStackedBarChart':
        final values = _numbers(el['values']);
        final n = math.min(labels.length, values.length);
        final slices = n > 0
            ? [
                for (var i = 0; i < n; i++)
                  (label: labels[i], value: values[i], color: t.chartColor(i)),
              ]
            // Upstream's legacy form: `PieChart([Slice("Rent", 700), …])`
            // (or `{category, value}` objects) in place of labels + values.
            : [
                for (final (i, s) in _legacySlices(el.list('labels')).indexed)
                  (label: s.$1, value: s.$2, color: t.chartColor(i)),
              ];
        if (slices.isEmpty) return const SizedBox.shrink();
        final chart = switch (el.type) {
          'PieChart' => _Pie(
            slices,
            donut: el.string('variant') == 'donut',
            semi: el.string('appearance') == 'semiCircular',
          ),
          'RadialChart' => _Radial(slices),
          _ => _StackedBar(slices),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [chart, const SizedBox(height: 12), _SliceLegend(slices)],
        );

      case 'ScatterChart':
        final sets = [
          for (final s in el.list('datasets').whereType<OpenUiElement>())
            (
              name: s.string('name') ?? '',
              points: [
                for (final p in s.list('points').whereType<OpenUiElement>())
                  (
                    x: (p.number('x') ?? 0).toDouble(),
                    y: (p.number('y') ?? 0).toDouble(),
                    z: p.number('z')?.toDouble(),
                  ),
              ],
            ),
        ];
        if (sets.every((s) => s.points.isEmpty)) return const SizedBox.shrink();
        return withAxes(
          _Scatter(sets),
          legend: _SeriesLegend([for (final s in sets) s.name]),
        );

      default:
        final series = <_Series>[
          for (final s in el.list('series').whereType<OpenUiElement>())
            (name: s.string('category') ?? '', values: _numbers(s['values'])),
        ];
        if (series.isEmpty || labels.isEmpty) return const SizedBox.shrink();
        final chart = switch (el.type) {
          'RadarChart' when labels.length >= 3 => _Radar(labels, series),
          'LineChart' || 'AreaChart' => _Line(
            labels,
            series,
            area: el.type == 'AreaChart',
            variant: el.string('variant'),
            height: el.number('height')?.toDouble(),
          ),
          _ => _Bars(
            labels,
            series,
            horizontal: el.type == 'HorizontalBarChart',
            stacked: el.string('variant') == 'stacked',
            height: el.number('height')?.toDouble(),
          ),
        };
        return withAxes(
          chart,
          legend: _SeriesLegend([for (final s in series) s.name]),
        );
    }
  }
}

/// `Slice(category, value)` elements or `{category, value}` maps.
List<(String, num)> _legacySlices(List<Object?> items) => [
  for (final item in items)
    if (item is OpenUiElement && item.type == 'Slice')
      (item.string('category') ?? '', item.number('value') ?? 0)
    else if (item is Map && item.containsKey('value'))
      (
        openUiToText(item['category'] ?? item['label']),
        openUiToNumber(item['value']) ?? 0,
      ),
];

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, this.trailing});

  final Color color;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: t.body(delta: -2.5))),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(
            trailing!,
            style: t
                .body(delta: -2.5, color: t.textMuted)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ],
    );
  }
}

class _SeriesLegend extends StatelessWidget {
  const _SeriesLegend(this.names);

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    // Always shown (upstream), unless there's nothing to name.
    if (names.every((n) => n.isEmpty)) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (var i = 0; i < names.length; i++)
          _LegendDot(color: t.chartColor(i), label: names[i]),
      ],
    );
  }
}

/// Label, value and share of the total for each slice; past six slices the
/// rest fold behind "Show more", like upstream.
class _SliceLegend extends StatefulWidget {
  const _SliceLegend(this.slices);

  final List<_Slice> slices;

  @override
  State<_SliceLegend> createState() => _SliceLegendState();
}

class _SliceLegendState extends State<_SliceLegend> {
  static const _folded = 6;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final slices = widget.slices;
    final total = slices.fold<num>(0, (a, s) => a + s.value);
    final canFold = slices.length > _folded;
    final shown = canFold && !_expanded ? slices.take(_folded) : slices;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final s in shown)
                _LegendDot(
                  color: s.color,
                  label: s.label,
                  trailing: total == 0
                      ? _compact(s.value)
                      : '${_compact(s.value)} · '
                            '${(s.value / total * 100).round()}%',
                ),
            ],
          ),
          if (canFold)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: t.primaryText,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? 'Show less'
                    : 'Show more (${slices.length - _folded})',
                style: t.body(
                  delta: -2.5,
                  weight: FontWeight.w600,
                  color: t.primaryText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie(this.slices, {required this.donut, required this.semi});

  final List<_Slice> slices;
  final bool donut;
  final bool semi;

  @override
  Widget build(BuildContext context) {
    const size = 190.0;
    final total = slices.fold<num>(0, (a, s) => a + s.value);
    final ring = donut ? 30.0 : size / 2 - 4;
    final sections = [
      for (final s in slices)
        PieChartSectionData(
          value: s.value.toDouble(),
          color: s.color,
          radius: ring,
          showTitle: false,
        ),
      // A semicircle is a full pie whose lower half is an invisible slice
      // the size of everything else, clipped away below.
      if (semi)
        PieChartSectionData(
          value: total.toDouble(),
          color: Colors.transparent,
          radius: ring,
          showTitle: false,
        ),
    ];
    final chart = SizedBox(
      height: size,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: donut ? size / 2 - 4 - ring : 0,
          sectionsSpace: 1.5,
          startDegreeOffset: semi ? 180 : -90,
          pieTouchData: PieTouchData(enabled: false),
        ),
      ),
    );
    if (!semi) return chart;
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: .52,
        child: chart,
      ),
    );
  }
}

/// Concentric 270° rings, one per slice, scaled to the largest value.
class _Radial extends StatelessWidget {
  const _Radial(this.slices);

  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: CustomPaint(
        painter: _RadialPainter(slices, OpenUiTheme.of(context).border),
        size: Size.infinite,
      ),
    );
  }
}

class _RadialPainter extends CustomPainter {
  _RadialPainter(this.slices, this.track);

  final List<_Slice> slices;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = slices.map((s) => s.value).fold<num>(0, math.max);
    if (maxValue <= 0) return;
    final center = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) / 2 - 2;
    final band = math.min(14.0, (outer * .75) / slices.length);
    final stroke = band * .72;
    const start = -math.pi / 2;
    const sweepMax = math.pi * 1.5;
    for (var i = 0; i < slices.length; i++) {
      final r = outer - stroke / 2 - i * band;
      if (r <= stroke) break;
      final rect = Rect.fromCircle(center: center, radius: r);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweepMax, false, paint..color = track);
      canvas.drawArc(
        rect,
        start,
        sweepMax * (slices[i].value / maxValue),
        false,
        paint..color = slices[i].color,
      );
    }
  }

  @override
  bool shouldRepaint(_RadialPainter old) =>
      old.slices != slices || old.track != track;
}

/// One horizontal bar split into the slices' shares.
class _StackedBar extends StatelessWidget {
  const _StackedBar(this.slices);

  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<num>(0, (a, s) => a + s.value);
    if (total <= 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            for (var i = 0; i < slices.length; i++)
              if (slices[i].value > 0)
                Expanded(
                  flex: math.max(1, (slices[i].value / total * 1000).round()),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: i < slices.length - 1 ? 2 : 0,
                    ),
                    color: slices[i].color,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

FlTitlesData _titles(List<String> labels, {required TextStyle style}) {
  final step = math.max(1, (labels.length / 6).ceil());
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 38,
        getTitlesWidget: (value, meta) => value == meta.max
            ? const SizedBox.shrink()
            : Text(_compact(value), style: style),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final i = value.round();
          if (i < 0 || i >= labels.length || i % step != 0) {
            return const SizedBox.shrink();
          }
          final text = labels[i].length > 10
              ? '${labels[i].substring(0, 9)}…'
              : labels[i];
          return SideTitleWidget(
            meta: meta,
            child: Text(text, style: style),
          );
        },
      ),
    ),
  );
}

FlGridData _grid(OpenUiThemeData t) => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) => FlLine(color: t.border, strokeWidth: .6),
);

class _Bars extends StatelessWidget {
  const _Bars(
    this.labels,
    this.series, {
    required this.horizontal,
    required this.stacked,
    this.height,
  });

  final List<String> labels;
  final List<_Series> series;
  final bool horizontal;
  final bool stacked;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    num at(_Series s, int i) => i < s.values.length ? s.values[i] : 0;
    final groupWidth = horizontal ? 14.0 : 22.0;
    final rodWidth = stacked
        ? groupWidth
        : math.max(4.0, groupWidth / series.length);
    final groups = [
      for (var i = 0; i < labels.length; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 2,
          barRods: stacked
              ? [
                  BarChartRodData(
                    toY: series.fold<num>(0, (a, s) => a + at(s, i)).toDouble(),
                    width: rodWidth,
                    borderRadius: BorderRadius.circular(3),
                    rodStackItems: () {
                      var from = 0.0;
                      return [
                        for (var j = 0; j < series.length; j++)
                          BarChartRodStackItem(
                            from,
                            from += at(series[j], i).toDouble(),
                            t.chartColor(j),
                          ),
                      ];
                    }(),
                  ),
                ]
              : [
                  for (var j = 0; j < series.length; j++)
                    BarChartRodData(
                      toY: at(series[j], i).toDouble(),
                      width: rodWidth,
                      color: t.chartColor(j),
                      borderRadius: BorderRadius.circular(3),
                    ),
                ],
        ),
    ];
    return SizedBox(
      height: horizontal
          ? math.max(180.0, labels.length * 34.0)
          : (height ?? 220),
      child: BarChart(
        BarChartData(
          rotationQuarterTurns: horizontal ? 1 : 0,
          barGroups: groups,
          alignment: BarChartAlignment.spaceAround,
          gridData: _grid(t),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            labels,
            style: t.body(delta: -4, color: t.textFaint),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => t.surfaceRaised,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${labels[group.x]}\n${_compact(rod.toY)}',
                t.body(delta: -3, color: t.textStrong),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(
    this.labels,
    this.series, {
    required this.area,
    this.variant,
    this.height,
  });

  final List<String> labels;
  final List<_Series> series;
  final bool area;
  final String? variant;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    return SizedBox(
      height: height ?? 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(0, labels.length - 1).toDouble(),
          gridData: _grid(t),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            labels,
            style: t.body(delta: -4, color: t.textFaint),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => t.surfaceRaised,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    _compact(s.y),
                    t.body(delta: -3, color: t.chartColor(s.barIndex)),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            for (var j = 0; j < series.length; j++)
              LineChartBarData(
                spots: [
                  for (
                    var i = 0;
                    i < math.min(labels.length, series[j].values.length);
                    i++
                  )
                    FlSpot(i.toDouble(), series[j].values[i].toDouble()),
                ],
                color: t.chartColor(j),
                barWidth: 2.5,
                isCurved: variant == 'natural',
                preventCurveOverShooting: true,
                isStepLineChart: variant == 'step',
                dotData: FlDotData(show: labels.length <= 12),
                belowBarData: BarAreaData(
                  show: area,
                  color: t.chartColor(j).withValues(alpha: .18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Radar extends StatelessWidget {
  const _Radar(this.labels, this.series);

  final List<String> labels;
  final List<_Series> series;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    return SizedBox(
      height: 240,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            for (var j = 0; j < series.length; j++)
              RadarDataSet(
                dataEntries: [
                  for (var i = 0; i < labels.length; i++)
                    RadarEntry(
                      value:
                          (i < series[j].values.length
                                  ? series[j].values[i]
                                  : 0)
                              .toDouble(),
                    ),
                ],
                fillColor: t.chartColor(j).withValues(alpha: .18),
                borderColor: t.chartColor(j),
                borderWidth: 2,
                entryRadius: 2.5,
              ),
          ],
          radarShape: RadarShape.polygon,
          radarBorderData: BorderSide(color: t.border),
          gridBorderData: BorderSide(color: t.border, width: .6),
          tickBorderData: BorderSide(color: t.border, width: .6),
          tickCount: 4,
          ticksTextStyle: const TextStyle(color: Colors.transparent),
          titleTextStyle: t.body(delta: -3.5, color: t.textMuted),
          titlePositionPercentageOffset: .12,
          getTitle: (index, _) => RadarChartTitle(text: labels[index]),
        ),
      ),
    );
  }
}

typedef _ScatterSet = ({
  String name,
  List<({double x, double y, double? z})> points,
});

class _Scatter extends StatelessWidget {
  const _Scatter(this.sets);

  final List<_ScatterSet> sets;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final zs = [
      for (final s in sets)
        for (final p in s.points)
          if (p.z != null) p.z!,
    ];
    final zMax = zs.isEmpty
        ? 1.0
        : zs.reduce(math.max).clamp(1e-9, double.infinity);
    final style = t.body(delta: -4, color: t.textFaint);
    return SizedBox(
      height: 220,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: [
            for (var j = 0; j < sets.length; j++)
              for (final p in sets[j].points)
                ScatterSpot(
                  p.x,
                  p.y,
                  dotPainter: FlDotCirclePainter(
                    radius: p.z == null ? 5 : 4 + 8 * (p.z! / zMax),
                    color: t.chartColor(j).withValues(alpha: .8),
                    strokeWidth: 0,
                  ),
                ),
          ],
          gridData: FlGridData(
            getDrawingHorizontalLine: (_) =>
                FlLine(color: t.border, strokeWidth: .6),
            getDrawingVerticalLine: (_) =>
                FlLine(color: t.border, strokeWidth: .6),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, meta) => Text(_compact(v), style: style),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(_compact(v), style: style),
                ),
              ),
            ),
          ),
          scatterTouchData: ScatterTouchData(enabled: false),
        ),
      ),
    );
  }
}
