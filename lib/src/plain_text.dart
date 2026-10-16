import 'lang.dart';
import 'library.dart';

/// A readable plain-text version of an openui-lang [program] — for copying
/// an answer, accessibility or notifications. Titles, text, list and table
/// rows and chart values; buttons and inputs are left out.
String openUiToPlainText(String program, {OpenUiLibrary? library}) {
  final lib = library ?? OpenUiLibrary.standard;
  final root = OpenUiEvaluator(
    OpenUiProgram.parse(program),
    {},
    signatures: lib.signatures,
  ).evaluateRoot();
  final lines = <String>[];
  _collect(root, lines);
  return lines.where((l) => l.trim().isNotEmpty).join('\n').trim();
}

const _skip = {
  'Button',
  'Buttons',
  'IconButton',
  'Icon',
  'Form',
  'Input',
  'TextArea',
  'Select',
  'DatePicker',
  'Slider',
  'CheckBoxGroup',
  'RadioGroup',
  'SwitchGroup',
  'Chips',
  'OptionCards',
  'Separator',
  'Modal',
};

const _textKeys = [
  'title',
  'heading',
  'name',
  'text',
  'textMarkdown',
  'trigger',
  'label',
  'value',
  'subtitle',
  'subtext',
  'description',
  'details',
  'body',
  'time',
];

void _collect(Object? v, List<String> out) {
  if (v is List) {
    for (final item in v) {
      _collect(item, out);
    }
    return;
  }
  if (v is! OpenUiElement || _skip.contains(v.type)) return;
  String s(String k) => v.string(k) ?? '';
  switch (v.type) {
    case 'Table':
      final cols = v.list('columns').whereType<OpenUiElement>().toList();
      if (cols.isEmpty) return;
      out.add(cols.map((c) => c.string('label') ?? '').join(' | '));
      final rows = cols
          .map((c) => c.list('data').length)
          .fold<int>(0, (a, b) => a > b ? a : b);
      for (var r = 0; r < rows; r++) {
        out.add(
          cols
              .map((c) {
                final d = c.list('data');
                final cell = r < d.length ? d[r] : null;
                return cell is OpenUiElement
                    ? openUiToPlainTextOf(cell)
                    : openUiToText(cell);
              })
              .join(' | '),
        );
      }
      return;
    case 'EntityList':
      for (final row in [v['header'], ...v.list('rows'), v['footer']]) {
        if (row is Map) {
          out.add(
            '${openUiToText(row['left'])}: ${openUiToText(row['right'])}',
          );
        }
      }
      return;
    case 'PieChart' || 'RadialChart' || 'SingleStackedBarChart':
      final labels = v.list('labels');
      final values = v.list('values');
      for (var i = 0; i < labels.length && i < values.length; i++) {
        out.add('${openUiToText(labels[i])}: ${openUiToText(values[i])}');
      }
      return;
    case 'BarChart' ||
        'LineChart' ||
        'AreaChart' ||
        'HorizontalBarChart' ||
        'RadarChart':
      final labels = v.list('labels').map(openUiToText).toList();
      for (final series in v.list('series').whereType<OpenUiElement>()) {
        final values = series.list('values');
        out.add(
          '${series.string('category') ?? ''}: ${[for (var i = 0; i < labels.length && i < values.length; i++) '${labels[i]} ${openUiToText(values[i])}'].join(', ')}',
        );
      }
      return;
    case 'TagBlock':
      out.add(v.list('tags').map(openUiToText).join(', '));
      return;
    case 'StepsItem':
      out.add(
        '• ${s('title')}${s('details').isEmpty ? '' : ' — ${s('details')}'}',
      );
      return;
  }
  for (final key in _textKeys) {
    final value = v[key];
    if (value is String && value.trim().isNotEmpty) out.add(value);
  }
  for (final entry in v.props.entries) {
    if (_textKeys.contains(entry.key)) continue;
    final value = entry.value is OpenUiBinding
        ? (entry.value as OpenUiBinding).value
        : entry.value;
    if (value is OpenUiElement || value is List) _collect(value, out);
    if (value is Map) {
      for (final nested in value.values) {
        _collect(nested, out);
      }
    }
  }
}

/// Plain text of a single evaluated element (e.g. a Tag in a table cell).
String openUiToPlainTextOf(OpenUiElement element) {
  final out = <String>[];
  _collect(element, out);
  return out.join(' ');
}
