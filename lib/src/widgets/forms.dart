import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lang.dart';
import '../theme.dart';
import '../view.dart';
import 'common.dart';
import 'data.dart' show openUiTrigger;
import 'layout.dart' show OpenUiPill;
import 'markdown.dart';

/// The values of one `Form`, kept by the [OpenUiView] so they survive
/// re-parses. Fields register on build in display order, which is the order
/// a submission lists them in.
///
/// Until the user touches a field its default stays live: a `defaultValue`
/// that streams in after the field first rendered still applies (upstream
/// `formDefaultValueUtils`).
class OpenUiFormController extends ChangeNotifier {
  OpenUiFormController(this.name);

  final String name;
  final _values = <String, Object?>{};
  final _rules = <String, Map>{};
  final _order = <String>[];
  final _touched = <String>{};
  final _shown = <String>{};

  /// Where each field is drawn, to bring the first invalid one into view.
  final _anchors = <String, BuildContext>{};

  void anchor(String field, BuildContext context) => _anchors[field] = context;

  void unanchor(String field, BuildContext context) {
    if (identical(_anchors[field], context)) _anchors.remove(field);
  }

  /// Adds or refreshes [field]: an untouched field takes the latest
  /// [initial]; the latest [rules] always apply. Doesn't notify (it runs
  /// during build).
  void register(String field, {Object? initial, Object? rules}) {
    if (!_values.containsKey(field)) _order.add(field);
    if (!_touched.contains(field)) _values[field] = initial;
    if (rules is Map) {
      _rules[field] = rules;
    } else {
      _rules.remove(field);
    }
  }

  bool has(String field) => _values.containsKey(field);
  Object? value(String field) => _values[field];
  bool isRequired(String field) => _rules[field]?['required'] == true;

  /// The user's (or a `$binding`'s) value for [field].
  void set(String field, Object? value) {
    if (!_values.containsKey(field)) _order.add(field);
    _touched.add(field);
    _values[field] = value;
    notifyListeners();
  }

  /// [field]'s error, once it has been shown (blur, change or submit).
  String? error(String field) => _shown.contains(field) ? _check(field) : null;

  /// Starts showing [field]'s error — on blur for text, on change for
  /// pickers.
  void showError(String field) {
    if (_shown.add(field)) notifyListeners();
  }

  /// Hides [field]'s error while the user edits it again.
  void hideError(String field) {
    if (_shown.remove(field)) notifyListeners();
  }

  /// Shows every field's errors; true when there are none.
  bool validate() {
    _shown.addAll(_order);
    notifyListeners();
    final invalid = _order.where((f) => _check(f) != null).firstOrNull;
    if (invalid == null) return true;
    // On a phone the first bad field is often scrolled away above the
    // submit button: bring it into view so the submit doesn't look dead.
    HapticFeedback.mediumImpact();
    final at = _anchors[invalid];
    if (at != null && at.mounted) {
      Scrollable.ensureVisible(
        at,
        alignment: .25,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
    return false;
  }

  /// Non-empty fields in display order.
  List<(String, Object?)> get entries => [
    for (final f in _order)
      if (!_isEmpty(_values[f])) (f, _values[f]),
  ];

  /// Values the user changed — what a view restores after being rebuilt.
  Map<String, Object?> get touchedValues => {
    for (final f in _touched) f: _values[f],
  };

  void restore(Map<String, Object?> values) {
    for (final e in values.entries) {
      if (!_values.containsKey(e.key)) _order.add(e.key);
      _values[e.key] = e.value;
      _touched.add(e.key);
    }
  }

  static bool _isEmpty(Object? v) =>
      v == null ||
      (v is String && v.trim().isEmpty) ||
      (v is List && v.isEmpty) ||
      (v is Map && !v.values.contains(true));

  // Messages and rules follow upstream lang-core `validation.ts`.
  String? _check(String field) {
    final rules = _rules[field];
    if (rules == null) return null;
    final v = _values[field];
    if (rules['required'] == true && _isEmpty(v)) {
      return v is Map
          ? 'At least one option is required'
          : 'This field is required';
    }
    if (_isEmpty(v)) return null;
    final text = v is String ? v.trim() : null;
    if (text != null) {
      if (rules['email'] == true &&
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
        return 'Please enter a valid email';
      }
      if (rules['url'] == true) {
        final uri = Uri.tryParse(text);
        if (uri == null || !uri.hasScheme) return 'Please enter a valid URL';
      }
      if (rules['numeric'] == true && num.tryParse(text) == null) {
        return 'Must be a number';
      }
      final pattern = rules['pattern'];
      if (pattern is String && pattern.isNotEmpty) {
        try {
          if (!RegExp(pattern).hasMatch(text)) return 'Invalid format';
        } on FormatException {
          // An invalid pattern from the model can't fail the user.
        }
      }
      final minLength = openUiToNumber(rules['minLength']);
      final maxLength = openUiToNumber(rules['maxLength']);
      if (minLength != null && text.length < minLength) {
        return 'Must be at least ${openUiToText(minLength)} characters';
      }
      if (maxLength != null && text.length > maxLength) {
        return 'Must be no more than ${openUiToText(maxLength)} characters';
      }
    }
    final n = openUiToNumber(v is List && v.isNotEmpty ? v.first : v);
    final min = openUiToNumber(rules['min']);
    final max = openUiToNumber(rules['max']);
    if (n != null && min != null && n < min) {
      return 'Must be at least ${openUiToText(min)}';
    }
    if (n != null && max != null && n > max) {
      return 'Must be no more than ${openUiToText(max)}';
    }
    return null;
  }
}

/// Provides the enclosing `Form`'s controller to its fields and buttons.
class OpenUiFormScope extends InheritedWidget {
  const OpenUiFormScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final OpenUiFormController controller;

  static OpenUiFormController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OpenUiFormScope>()?.controller;

  @override
  bool updateShouldNotify(OpenUiFormScope old) => controller != old.controller;
}

/// Where a field keeps its value: the enclosing form, or (outside any form,
/// e.g. a search box bound to `$search`) a view-level store.
OpenUiFormController _controllerOf(BuildContext context) =>
    OpenUiFormScope.maybeOf(context) ?? OpenUiScope.of(context).form('');

/// Shared plumbing of every input: register the field (keeping its default
/// live until touched), read its value — a `$binding` is the source of
/// truth when present — and write changes to the form and the binding.
mixin _FieldMixin<W extends StatefulWidget> on State<W> {
  OpenUiElement get field;
  String get fieldName => field.string('name') ?? '';

  /// The default before the user touches the field.
  Object? get initialValue => null;

  late OpenUiFormController controller;

  void _register() {
    controller = _controllerOf(context);
    controller.anchor(fieldName, context);
    controller.register(
      fieldName,
      initial: initialValue,
      rules: field['rules'],
    );
    // A bound field follows its `$state` (e.g. `@Reset($search)` clears it);
    // the form mirrors it so a submit still carries the value.
    final binding = field.binding('value');
    if (binding != null &&
        binding.value != null &&
        binding.value != controller.value(fieldName)) {
      controller.register(fieldName, rules: field['rules']);
      controller.restore({fieldName: binding.value});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  @override
  void dispose() {
    controller.unanchor(fieldName, context);
    super.dispose();
  }

  Object? get value {
    final binding = field.binding('value');
    return binding != null && binding.value != null
        ? binding.value
        : controller.value(fieldName);
  }

  bool get enabled => !OpenUiScope.of(context).isStreaming;

  /// Pickers (chips, cards, radios, toggles, sliders, dates) tick and check
  /// their rules as they change; text fields check on blur instead.
  bool get isDiscrete => true;

  void write(Object? v) {
    if (isDiscrete && v != controller.value(fieldName)) {
      HapticFeedback.selectionClick();
    }
    controller.set(fieldName, v);
    if (isDiscrete) {
      controller.showError(fieldName);
    } else {
      controller.hideError(fieldName);
    }
    final binding = field.binding('value');
    if (binding != null) OpenUiScope.of(context).setVar(binding.name, v);
    setState(() {});
  }
}

InputDecoration _decoration(
  OpenUiThemeData t, {
  String? hint,
  bool error = false,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: t.surfaceSunk,
    hintText: hint,
    hintStyle: t.body(delta: -1, color: t.textFaint),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    enabledBorder: border(error ? t.danger : t.border),
    disabledBorder: border(t.border),
    focusedBorder: border(error ? t.danger : t.primary, 1.4),
    border: border(t.border),
  );
}

// ── Form & FormControl ─────────────────────────────────────────────────────

class OpenUiForm extends StatelessWidget {
  const OpenUiForm(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final controller = OpenUiScope.of(
      context,
    ).form(el.string('name') ?? 'form');
    final fields = openUiFlatten(el['fields']);
    return OpenUiFormScope(
      controller: controller,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in fields) ...[
            OpenUiBlock(f),
            const SizedBox(height: 16),
          ],
          OpenUiBlock(el['buttons']),
        ],
      ),
    );
  }
}

class OpenUiFormControl extends StatelessWidget {
  const OpenUiFormControl(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final input = el['input'];
    final name = input is OpenUiElement ? input.string('name') ?? '' : '';
    final label = el.string('label') ?? '';
    final hint = el.string('hint') ?? '';
    final controller = _controllerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (input is OpenUiElement &&
                    input['rules'] is Map &&
                    (input['rules'] as Map)['required'] == true)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: t.danger),
                  ),
              ],
            ),
            style: t.body(
              delta: -1,
              weight: FontWeight.w600,
              color: t.textStrong,
            ),
          ),
          const SizedBox(height: 8),
        ],
        OpenUiBlock(input),
        // The error replaces the hint while there is one.
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final error = controller.error(name);
            if (error == null) {
              if (hint.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  hint,
                  style: t.body(delta: -2.5, color: t.textMuted),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1, right: 4),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: t.danger,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      error,
                      style: t.body(delta: -2.5, color: t.danger),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class OpenUiLabel extends StatelessWidget {
  const OpenUiLabel(this.el, {super.key});

  final OpenUiElement el;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    return Text(
      el.string('text') ?? '',
      style: t.body(delta: -1, weight: FontWeight.w600, color: t.textStrong),
    );
  }
}

/// Whether [controller] has an error to show for [name] right now.
bool _hasError(OpenUiFormController controller, String name) =>
    controller.error(name) != null;

// ── Text inputs ────────────────────────────────────────────────────────────

/// `Input` and `TextArea`.
class OpenUiTextInput extends StatefulWidget {
  const OpenUiTextInput(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiTextInput> createState() => _OpenUiTextInputState();
}

class _OpenUiTextInputState extends State<OpenUiTextInput>
    with _FieldMixin<OpenUiTextInput> {
  TextEditingController? _text;
  final _focus = FocusNode();

  @override
  OpenUiElement get field => widget.el;

  @override
  bool get isDiscrete => false;

  @override
  void initState() {
    super.initState();
    // Upstream: check on blur, clear the error while editing.
    _focus.addListener(() {
      if (_focus.hasFocus) {
        controller.hideError(fieldName);
      } else {
        controller.showError(fieldName);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text ??= TextEditingController(text: openUiToText(value));
  }

  @override
  void didUpdateWidget(OpenUiTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A `$binding` changed from elsewhere (e.g. `@Reset($search)`).
    final text = openUiToText(value);
    if (_text != null && _text!.text != text && !_focus.hasFocus) {
      _text!.text = text;
    }
  }

  @override
  void dispose() {
    _text?.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final el = widget.el;
    final area = el.type == 'TextArea';
    final type = el.string('type');
    final rows = (el.number('rows') ?? 3).toInt().clamp(1, 12);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        controller: _text,
        focusNode: _focus,
        enabled: enabled,
        onChanged: write,
        onTapOutside: (_) => _focus.unfocus(),
        style: t.body(),
        cursorColor: t.primary,
        obscureText: type == 'password',
        minLines: area ? rows : 1,
        maxLines: area ? rows + 4 : 1,
        keyboardType: area
            ? TextInputType.multiline
            : switch (type) {
                'email' => TextInputType.emailAddress,
                'number' => const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                'url' => TextInputType.url,
                _ => TextInputType.text,
              },
        decoration: _decoration(
          t,
          hint: el.string('placeholder'),
          error: _hasError(controller, fieldName),
        ),
      ),
    );
  }
}

// ── Select ─────────────────────────────────────────────────────────────────

class OpenUiSelect extends StatefulWidget {
  const OpenUiSelect(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiSelect> createState() => _OpenUiSelectState();
}

class _OpenUiSelectState extends State<OpenUiSelect>
    with _FieldMixin<OpenUiSelect> {
  @override
  OpenUiElement get field => widget.el;

  // Items without a value can't be selected (upstream filters them).
  List<(String, String)> get _items => [
    for (final item in widget.el.list('items').whereType<OpenUiElement>())
      if ((item.string('value') ?? '').isNotEmpty)
        (item.string('value')!, item.string('label') ?? item.string('value')!),
  ];

  Future<void> _pick() async {
    final t = OpenUiTheme.of(context);
    final items = _items;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.surfaceRaised,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius + 4)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .6,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              for (final (v, label) in items)
                ListTile(
                  title: Text(label, style: t.body()),
                  trailing: v == openUiToText(value)
                      ? Icon(Icons.check_rounded, color: t.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(v),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) write(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final current = openUiToText(value);
    final label = _items
        .where((i) => i.$1 == current && current.isNotEmpty)
        .map((i) => i.$2)
        .firstOrNull;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => InkWell(
        onTap: enabled ? _pick : null,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          isEmpty: label == null,
          decoration: _decoration(
            t,
            hint: widget.el.string('placeholder') ?? 'Select…',
            error: _hasError(controller, fieldName),
            suffix: Icon(Icons.expand_more_rounded, color: t.textMuted),
          ),
          child: label == null ? null : Text(label, style: t.body()),
        ),
      ),
    );
  }
}

// ── DatePicker ─────────────────────────────────────────────────────────────

class OpenUiDatePicker extends StatefulWidget {
  const OpenUiDatePicker(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiDatePicker> createState() => _OpenUiDatePickerState();
}

class _OpenUiDatePickerState extends State<OpenUiDatePicker>
    with _FieldMixin<OpenUiDatePicker> {
  @override
  OpenUiElement get field => widget.el;

  bool get _range => widget.el.string('mode') == 'range';

  Future<void> _pick() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 100);
    final last = DateTime(now.year + 20);
    if (_range) {
      final current = value is DateTimeRange ? value as DateTimeRange : null;
      final picked = await showDateRangePicker(
        context: context,
        firstDate: first,
        lastDate: last,
        initialDateRange: current,
      );
      if (picked != null) write(picked);
    } else {
      final current = value is DateTime ? value as DateTime : now;
      final picked = await showDatePicker(
        context: context,
        firstDate: first,
        lastDate: last,
        initialDate: current,
      );
      if (picked != null) write(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final v = value;
    final text = v is DateTime || v is DateTimeRange
        ? openUiFieldText(v)
        : null;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => InkWell(
        onTap: enabled ? _pick : null,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          isEmpty: text == null,
          decoration: _decoration(
            t,
            hint: _range ? 'Pick dates' : 'Pick a date',
            error: _hasError(controller, fieldName),
            suffix: Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: t.textMuted,
            ),
          ),
          child: text == null ? null : Text(text, style: t.body()),
        ),
      ),
    );
  }
}

// ── Slider ─────────────────────────────────────────────────────────────────

class OpenUiSliderField extends StatefulWidget {
  const OpenUiSliderField(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiSliderField> createState() => _OpenUiSliderFieldState();
}

class _OpenUiSliderFieldState extends State<OpenUiSliderField>
    with _FieldMixin<OpenUiSliderField> {
  @override
  OpenUiElement get field => widget.el;

  double get _min => (widget.el.number('min') ?? 0).toDouble();
  double get _max {
    final max = (widget.el.number('max') ?? 100).toDouble();
    return max > _min ? max : _min + 1;
  }

  @override
  Object? get initialValue {
    final d = widget.el['defaultValue'];
    final list = d is List ? d : (d == null ? const [] : [d]);
    final nums = list.map(openUiToNumber).whereType<num>().toList();
    return nums.isEmpty ? [_min] : nums;
  }

  List<double> get _values {
    final v = value;
    final list = v is List ? v : [v];
    final nums = list
        .map(openUiToNumber)
        .whereType<num>()
        .map((n) => n.toDouble().clamp(_min, _max))
        .toList();
    return nums.isEmpty ? [_min] : nums;
  }

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final el = widget.el;
    // Upstream steps by max(1, step) for both variants, so values snap to
    // whole steps; the label falls back to the field name.
    final step = (el.number('step')?.toDouble() ?? 1).clamp(
      1.0,
      double.infinity,
    );
    final divisions = ((_max - _min) / step).round().clamp(1, 1000);
    final values = _values;
    String fmt(double v) => openUiToText(v.roundToDouble());
    final label = el.string('label') ?? fieldName;
    final sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: t.primary,
      inactiveTrackColor: t.border,
      thumbColor: t.primary,
      overlayColor: t.primary.withValues(alpha: .12),
      valueIndicatorColor: t.surfaceRaised,
      valueIndicatorTextStyle: t.body(delta: -2, color: t.textStrong),
    );
    num out(double v) => (_min + ((v - _min) / step).round() * step).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: t.body(delta: -2, color: t.textMuted)),
            ),
            Text(
              values.length > 1
                  ? '${fmt(values.first)} – ${fmt(values.last)}'
                  : fmt(values.first),
              style: t.body(
                delta: -1,
                weight: FontWeight.w600,
                color: t.textStrong,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: sliderTheme,
          child: values.length > 1
              ? RangeSlider(
                  min: _min,
                  max: _max,
                  divisions: divisions,
                  values: RangeValues(values.first, values.last),
                  labels: RangeLabels(fmt(values.first), fmt(values.last)),
                  onChanged: enabled
                      ? (r) => write([out(r.start), out(r.end)])
                      : null,
                )
              : Slider(
                  min: _min,
                  max: _max,
                  divisions: divisions,
                  value: values.first,
                  label: fmt(values.first),
                  onChanged: enabled ? (v) => write([out(v)]) : null,
                ),
        ),
        Row(
          children: [
            Text(fmt(_min), style: t.body(delta: -3, color: t.textFaint)),
            const Spacer(),
            Text(fmt(_max), style: t.body(delta: -3, color: t.textFaint)),
          ],
        ),
      ],
    );
  }
}

// ── CheckBoxGroup / SwitchGroup ────────────────────────────────────────────

/// `CheckBoxGroup` and `SwitchGroup`; the value is `{itemName: checked}`.
class OpenUiToggleGroup extends StatefulWidget {
  const OpenUiToggleGroup(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiToggleGroup> createState() => _OpenUiToggleGroupState();
}

class _OpenUiToggleGroupState extends State<OpenUiToggleGroup>
    with _FieldMixin<OpenUiToggleGroup> {
  @override
  OpenUiElement get field => widget.el;

  List<OpenUiElement> get _items =>
      widget.el.list('items').whereType<OpenUiElement>().toList();

  @override
  Object? get initialValue => {
    for (final item in _items)
      item.string('name') ?? item.string('label') ?? '': item.boolean(
        'defaultChecked',
      ),
  };

  Map<String, bool> get _checked {
    final v = value;
    return v is Map
        ? {for (final e in v.entries) e.key.toString(): e.value == true}
        : {};
  }

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final switches = widget.el.type == 'SwitchGroup';
    final checked = _checked;
    final rows = <Widget>[];
    for (final item in _items) {
      final key = item.string('name') ?? item.string('label') ?? '';
      final on = checked[key] ?? false;
      final label = item.string('label') ?? '';
      final description = item.string('description') ?? '';
      void toggle([bool? to]) => write({...checked, key: to ?? !on});
      final control = switches
          ? Switch(
              value: on,
              onChanged: enabled ? toggle : null,
              activeTrackColor: t.primary,
            )
          : Checkbox(
              value: on,
              onChanged: enabled ? (v) => toggle(v ?? false) : null,
              activeColor: t.primary,
              checkColor: t.onPrimary,
              side: BorderSide(color: t.borderStrong, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            );
      final text = Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.body(delta: -.5, color: t.textStrong)),
            if (description.isNotEmpty)
              Text(description, style: t.body(delta: -2.5, color: t.textMuted)),
          ],
        ),
      );
      rows.add(
        InkWell(
          onTap: enabled ? toggle : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: switches
                  ? [text, control]
                  : [
                      SizedBox(width: 32, height: 36, child: control),
                      const SizedBox(width: 6),
                      text,
                    ],
            ),
          ),
        ),
      );
    }
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
    if (!switches) return column;
    return OpenUiSurface(
      variant: widget.el.string('variant') ?? 'clear',
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: column,
    );
  }
}

// ── RadioGroup ─────────────────────────────────────────────────────────────

class OpenUiRadioGroup extends StatefulWidget {
  const OpenUiRadioGroup(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiRadioGroup> createState() => _OpenUiRadioGroupState();
}

class _OpenUiRadioGroupState extends State<OpenUiRadioGroup>
    with _FieldMixin<OpenUiRadioGroup> {
  @override
  OpenUiElement get field => widget.el;

  @override
  Object? get initialValue => widget.el.string('defaultValue');

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final current = openUiToText(value);
    final items = widget.el.list('items').whereType<OpenUiElement>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          Builder(
            builder: (context) {
              final v = item.string('value') ?? item.string('label') ?? '';
              final selected = v == current;
              final description = item.string('description') ?? '';
              return InkWell(
                onTap: enabled ? () => write(v) : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(top: 2, right: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? t.primary : t.borderStrong,
                            width: selected ? 5.5 : 1.4,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.string('label') ?? v,
                              style: t.body(delta: -.5, color: t.textStrong),
                            ),
                            if (description.isNotEmpty)
                              Text(
                                description,
                                style: t.body(delta: -2.5, color: t.textMuted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── Chips / OptionCards ────────────────────────────────────────────────────

/// `Chips` and `OptionCards`: one value (`type: "single"`, a string) or
/// several (`"multiple"`, a list).
class OpenUiChoiceGroup extends StatefulWidget {
  const OpenUiChoiceGroup(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiChoiceGroup> createState() => _OpenUiChoiceGroupState();
}

class _OpenUiChoiceGroupState extends State<OpenUiChoiceGroup>
    with _FieldMixin<OpenUiChoiceGroup> {
  @override
  OpenUiElement get field => widget.el;

  // Upstream defaults: Chips select many, OptionCards one.
  bool get _multiple =>
      (widget.el.string('type') ??
          (widget.el.type == 'Chips' ? 'multiple' : 'single')) ==
      'multiple';

  List<OpenUiElement> get _items => [
    for (final item in widget.el.list('items').whereType<OpenUiElement>())
      if ((item.string('value') ?? '').isNotEmpty) item,
  ];

  @override
  Object? get initialValue {
    final d = widget.el['defaultValue'];
    if (_multiple) {
      return d is List
          ? d.map(openUiToText).toList()
          : (d == null ? <String>[] : [openUiToText(d)]);
    }
    return d is List
        ? (d.isEmpty ? null : openUiToText(d.first))
        : d?.toString();
  }

  Set<String> get _selected {
    final v = value;
    if (v is List) return v.map(openUiToText).toSet();
    return v == null || openUiToText(v).isEmpty ? {} : {openUiToText(v)};
  }

  void _toggle(String v) {
    final selected = _selected;
    if (_multiple) {
      final next = selected.contains(v)
          ? (selected..remove(v))
          : (selected..add(v));
      write(next.toList());
    } else {
      // Tapping the selected option again clears it (upstream).
      write(selected.contains(v) ? null : v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final selected = _selected;
    if (widget.el.type == 'Chips') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            Builder(
              builder: (context) {
                final v = item.string('value') ?? '';
                final disabled = item.boolean('disabled') || !enabled;
                return Opacity(
                  opacity: item.boolean('disabled') ? .45 : 1,
                  child: OpenUiPill(
                    label: item.string('label') ?? v,
                    icon: openUiIconOf(item['icon']),
                    showCheck: true,
                    selected: selected.contains(v),
                    onTap: disabled ? null : () => _toggle(v),
                  ),
                );
              },
            ),
        ],
      );
    }
    return OpenUiBalancedGrid(
      maxPerRow: 3,
      children: [
        for (final item in items)
          _OptionCard(
            item: item,
            selected: selected.contains(item.string('value') ?? ''),
            onTap: item.boolean('disabled') || !enabled
                ? null
                : () => _toggle(item.string('value') ?? ''),
          ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.item, required this.selected, this.onTap});

  final OpenUiElement item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final top = item['topContent'];
    final icon = openUiIconOf(top);
    final subtitle = item.string('subtitle') ?? '';
    final hasTop =
        icon != null || (top is OpenUiElement && top.type == 'Image');
    final tick = AnimatedOpacity(
      opacity: selected ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(Icons.check_circle_rounded, size: 18, color: t.primary),
      ),
    );
    return Opacity(
      opacity: item.boolean('disabled') ? .45 : 1,
      child: Material(
        color: selected ? t.primarySoft : t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radius - 2),
          side: BorderSide(
            color: selected ? t.primary : t.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon or image on top, with the tick beside it; a text-only
                // card puts the tick next to its title instead of leaving an
                // empty band above it.
                if (hasTop) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (icon != null) ...[
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: selected
                                ? t.primary.withValues(alpha: .18)
                                : t.chip,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: selected ? t.primaryText : t.text,
                          ),
                        ),
                        const Spacer(),
                      ] else
                        Expanded(
                          child: OpenUiNetworkImage(
                            src: (top as OpenUiElement).string('src'),
                            alt: top.string('alt'),
                            height: 72,
                            radius: 8,
                          ),
                        ),
                      tick,
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.string('title') ?? '',
                            style: t.body(
                              delta: -1,
                              weight: FontWeight.w600,
                              color: t.textStrong,
                              height: 1.3,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            OpenUiInlineMarkdown(
                              subtitle,
                              style: t.body(
                                delta: -2.5,
                                color: t.textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!hasTop) tick,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── EditableTable ──────────────────────────────────────────────────────────

/// `EditableTable(name, columns, data)`: cells edit inline. Once edited, a
/// bar shows "N changes made" with Reset and Save Changes; saving stores the
/// rows under `name` and sends them like a form submit (upstream
/// `EditableTable` / `EditableTableChangesBar`).
class OpenUiEditableTable extends StatefulWidget {
  const OpenUiEditableTable(this.el, {super.key});

  final OpenUiElement el;

  @override
  State<OpenUiEditableTable> createState() => _OpenUiEditableTableState();
}

class _OpenUiEditableTableState extends State<OpenUiEditableTable> {
  /// What edits are compared against: the streamed data, then whatever was
  /// last saved.
  List<List<String>>? _baseline;
  List<List<String>>? _rows;
  final _controllers = <String, TextEditingController>{};

  List<Map> get _columns => widget.el.list('columns').whereType<Map>().toList();

  List<List<String>> _dataRows() => [
    for (final row in widget.el.list('data').whereType<Map>())
      [
        for (var c = 0; c < _columns.length; c++)
          (row['values'] is List && c < (row['values'] as List).length)
              ? openUiToText((row['values'] as List)[c])
              : '',
      ],
  ];

  List<List<String>> _copy(List<List<String>> rows) => [
    for (final r in rows) [...r],
  ];

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _header(Map col) => openUiToText(col['header'] ?? col['key'] ?? '');

  int get _changes {
    final rows = _rows, base = _baseline;
    if (rows == null || base == null) return 0;
    var n = 0;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        if (r >= base.length ||
            c >= base[r].length ||
            rows[r][c] != base[r][c]) {
          n++;
        }
      }
    }
    return n;
  }

  void _reset() {
    setState(() {
      _rows = _copy(_baseline ?? _dataRows());
      for (final e in _controllers.entries) {
        final [r, c] = e.key.split(':').map(int.parse).toList();
        e.value.text = _rows![r][c];
      }
    });
  }

  void _save(BuildContext context) {
    final name = widget.el.string('name') ?? 'table';
    final cols = _columns;
    final rows = _rows ?? _dataRows();
    final text = [
      for (var r = 0; r < rows.length; r++)
        'Row ${r + 1} (${[for (var c = 0; c < cols.length; c++) '${_header(cols[c])}: ${rows[r][c]}'].join(', ')})',
    ].join('; ');
    final form =
        OpenUiFormScope.maybeOf(context) ?? OpenUiScope.of(context).form(name);
    form.set(name, text);
    OpenUiScope.of(context).runAction(
      OpenUiAction.toAssistant('Save Changes'),
      form: form,
      validate: false,
    );
    setState(() => _baseline = _copy(rows));
  }

  Widget _cell(BuildContext context, Map col, int r, int c, bool enabled) {
    final t = OpenUiTheme.of(context);
    final rows = _rows!;
    final type = openUiToText(col['type']);
    final value = rows[r][c];
    void set(String v) => setState(() => rows[r][c] = v);
    if (type == 'select' || type == 'date-single') {
      return InkWell(
        onTap: !enabled
            ? null
            : () async {
                if (type == 'date-single') {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.tryParse(value) ?? DateTime.now(),
                  );
                  if (picked != null) set(openUiFieldText(picked));
                  return;
                }
                final options =
                    (col['options'] is List ? col['options'] as List : const [])
                        .whereType<Map>()
                        .toList();
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: t.surfaceRaised,
                  builder: (context) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          ListTile(
                            title: Text(
                              openUiToText(o['label'] ?? o['value']),
                              style: t.body(),
                            ),
                            trailing: openUiToText(o['value']) == value
                                ? Icon(Icons.check_rounded, color: t.primary)
                                : null,
                            onTap: () => Navigator.of(
                              context,
                            ).pop(openUiToText(o['value'])),
                          ),
                      ],
                    ),
                  ),
                );
                if (picked != null) set(picked);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(value, style: t.body(delta: -1.5))),
              const SizedBox(width: 4),
              Icon(
                type == 'select'
                    ? Icons.expand_more_rounded
                    : Icons.calendar_today_rounded,
                size: 14,
                color: t.textFaint,
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controllers.putIfAbsent(
      '$r:$c',
      () => TextEditingController(text: value),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: set,
      style: t.body(delta: -1.5),
      cursorColor: t.primary,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      keyboardType: switch (type) {
        'number' => const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        'url' => TextInputType.url,
        _ => TextInputType.text,
      },
      textAlign: type == 'number' ? TextAlign.right : TextAlign.left,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = OpenUiTheme.of(context);
    final streaming = OpenUiScope.of(context).isStreaming;
    final cols = _columns;
    if (cols.isEmpty) return const SizedBox.shrink();
    // Follow the streamed data until it lands and the user starts editing.
    if (streaming || _rows == null) {
      final data = _dataRows();
      if (_changes == 0) {
        _rows = _copy(data);
        _baseline = _copy(data);
      }
    }
    final rows = _rows!;
    final changes = _changes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radius - 2),
            border: Border.all(color: t.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(120),
              columnWidths: {
                for (var c = 0; c < cols.length; c++)
                  if (openUiToNumber(cols[c]['width']) != null)
                    c: FixedColumnWidth(
                      openUiToNumber(cols[c]['width'])!.toDouble(),
                    ),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(color: t.border, width: .8),
                verticalInside: BorderSide(color: t.border, width: .8),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: t.surfaceSunk),
                  children: [
                    for (final col in cols)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Text(
                          _header(col),
                          style: t.body(
                            delta: -1.5,
                            weight: FontWeight.w600,
                            color: t.textStrong,
                          ),
                        ),
                      ),
                  ],
                ),
                for (var r = 0; r < rows.length; r++)
                  TableRow(
                    children: [
                      for (var c = 0; c < cols.length; c++)
                        _cell(context, cols[c], r, c, !streaming),
                    ],
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: changes == 0
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          changes == 1
                              ? '1 change made'
                              : '$changes changes made',
                          style: t.body(delta: -2, color: t.textMuted),
                        ),
                      ),
                      TextButton(
                        onPressed: _reset,
                        style: TextButton.styleFrom(
                          foregroundColor: t.textStrong,
                        ),
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: streaming ? null : () => _save(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: t.primary,
                          foregroundColor: t.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Used by buttons inside forms; exported so custom components can submit
/// the enclosing form the same way.
void openUiSubmit(BuildContext context, OpenUiAction action) =>
    openUiTrigger(context, action);
