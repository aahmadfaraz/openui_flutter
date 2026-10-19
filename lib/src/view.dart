import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'lang.dart';
import 'library.dart';
import 'reveal.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/forms.dart';

/// Turns a `@ToAssistant` message plus the form values (and tapped-card
/// context) it was sent with into the text of the user's next message.
typedef OpenUiSubmissionFormatter =
    String Function(String message, OpenUiSubmission submission);

/// What a `@ToAssistant` step carries besides its message.
class OpenUiSubmission {
  const OpenUiSubmission({this.formName, this.values = const [], this.context});

  /// The `Form` the button sits in, if any.
  final String? formName;

  /// The form's non-empty fields in display order, as (name, value).
  final List<(String, Object?)> values;

  /// Extra context, e.g. which card of a card block was tapped.
  final String? context;

  bool get isEmpty => values.isEmpty && (context == null || context!.isEmpty);
}

/// The default [OpenUiSubmissionFormatter]:
///
/// ```text
/// Build my routine
///
/// My choices: goal: fat-loss; days: 3; equipment: dumbbells, bands.
/// ```
String openUiDefaultSubmission(String message, OpenUiSubmission submission) {
  final parts = [message];
  if (submission.values.isNotEmpty) {
    final choices = submission.values
        .map((e) => '${e.$1}: ${openUiFieldText(e.$2)}')
        .join('; ');
    parts.add('My choices: $choices.');
  }
  if (submission.context != null && submission.context!.isNotEmpty) {
    parts.add(submission.context!);
  }
  return parts.where((p) => p.trim().isNotEmpty).join('\n\n');
}

/// A view's runtime state: changed `$variables` and form values — what to
/// keep (e.g. per chat message) so a view rebuilt after scrolling away comes
/// back as the user left it.
@immutable
class OpenUiSnapshot {
  const OpenUiSnapshot({this.vars = const {}, this.forms = const {}});

  final Map<String, Object?> vars;

  /// Form name → field → value ('' holds fields outside any form).
  final Map<String, Map<String, Object?>> forms;

  bool get isEmpty => vars.isEmpty && forms.values.every((f) => f.isEmpty);
}

/// Renders one openui-lang program (see `splitOpenUi`) as Flutter widgets.
///
/// The view owns the program's runtime state: `$variables`, form values and
/// component state (open tabs, accordion sections) live here, so they
/// survive the re-parse on every streamed chunk.
class OpenUiView extends StatefulWidget {
  const OpenUiView({
    super.key,
    required this.program,
    this.library,
    this.theme,
    this.isStreaming = false,
    this.onSendPrompt,
    this.onOpenUrl,
    this.formatSubmission = openUiDefaultSubmission,
    this.initialState,
    this.onStateChanged,
    this.smoothReveal = true,
  });

  /// openui-lang source. May be incomplete while [isStreaming].
  final String program;

  /// Components the program may use; [OpenUiLibrary.standard] by default.
  final OpenUiLibrary? library;

  /// Overrides the ambient [OpenUiTheme].
  final OpenUiThemeData? theme;

  /// More of the program may still arrive. Inputs and buttons are disabled
  /// until it lands, like the web renderer.
  final bool isStreaming;

  /// Called with the user's next message when a button runs
  /// `@ToAssistant` (or has no action). Buttons are inert when null.
  final ValueChanged<String>? onSendPrompt;

  /// `@OpenUrl`; opens the URL externally when null.
  final ValueChanged<Uri>? onOpenUrl;

  /// How a submission's message, form values and context become text.
  final OpenUiSubmissionFormatter formatSubmission;

  /// State to restore — a snapshot [onStateChanged] reported earlier.
  final OpenUiSnapshot? initialState;

  /// Called whenever the user changes a value or `$variable`.
  final ValueChanged<OpenUiSnapshot>? onStateChanged;

  /// While streaming, type text out at a steady pace (frame by frame)
  /// instead of showing each network chunk as it lands; structure appears
  /// instantly. See [OpenUiReveal].
  final bool smoothReveal;

  @override
  State<OpenUiView> createState() => _OpenUiViewState();
}

class _OpenUiViewState extends State<OpenUiView>
    with SingleTickerProviderStateMixin {
  late OpenUiProgram _program;
  late String _source;
  final _reveal = OpenUiReveal();
  /// Created on the first reveal: history never needs one.
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  Duration _lastParse = Duration.zero;
  final _state = <String, Object?>{};
  final _forms = <String, OpenUiFormController>{};

  /// `$variables` still holding their declared default. A default that was
  /// cut off mid-stream (`"hel`) is replaced once the full statement lands
  /// (upstream store `pristine`).
  final _pristine = <String>{};

  /// Bumped whenever `$state` or view state changes, so cached components
  /// (see [OpenUiBlock]) rebuild then — some read state straight off the
  /// scope rather than through their props.
  var _stateVersion = 0;

  OpenUiLibrary get _library => widget.library ?? OpenUiLibrary.standard;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialState;
    if (initial != null) {
      _state.addAll(initial.vars);
      for (final f in initial.forms.entries) {
        _form(f.key).restore(f.value);
      }
    }
    // A turn that streams in types out from the start; history renders
    // whole.
    _reveal.reset(
      widget.program,
      revealed: !(widget.smoothReveal && widget.isStreaming),
    );
    _parse(_reveal.visible);
    _startReveal();
  }

  /// Streaming as far as the components know: until the reveal has caught
  /// up, buttons stay disabled and new components ease in.
  bool get _streaming => widget.isStreaming || !_reveal.done;

  void _startReveal() {
    final ticker = _ticker ??= createTicker(_tick);
    if (_reveal.done || ticker.isActive) return;
    _lastTick = Duration.zero;
    _lastParse = Duration.zero;
    ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    final moved = _reveal.advance(dt, hurry: !widget.isStreaming);
    // Parse at most ~30 times a second; the last step always lands.
    if (moved &&
        (_reveal.done ||
            elapsed - _lastParse >= const Duration(milliseconds: 33))) {
      _lastParse = elapsed;
      setState(() => _parse(_reveal.visible));
    }
    if (_reveal.done) {
      _ticker?.stop();
      // The final frame flips `isStreaming` off for the components.
      if (!widget.isStreaming) setState(() {});
    }
  }

  OpenUiSnapshot get _snapshot => OpenUiSnapshot(
    vars: {
      for (final e in _state.entries)
        if (!_pristine.contains(e.key)) e.key: e.value,
    },
    forms: {for (final f in _forms.entries) f.key: f.value.touchedValues},
  );

  void _emit() => widget.onStateChanged?.call(_snapshot);

  @override
  void didUpdateWidget(OpenUiView old) {
    super.didUpdateWidget(old);
    if (widget.program != _reveal.target) {
      if (widget.smoothReveal && _streaming) {
        _reveal.retarget(widget.program);
      } else {
        _reveal.reset(widget.program, revealed: true);
      }
    }
    if (!widget.smoothReveal) _reveal.finish();
    if (_reveal.visible != _source) _parse(_reveal.visible);
    _startReveal();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    for (final form in _forms.values) {
      form.dispose();
    }
    super.dispose();
  }

  OpenUiEvaluator _evaluator() =>
      OpenUiEvaluator(_program, _state, signatures: _library.signatures);

  void _parse(String source) {
    _source = source;
    _program = OpenUiProgram.parse(_source);
    // Seed newly declared state; values the user already changed stay.
    for (final entry in _program.stateDefaults.entries) {
      if (_state.containsKey(entry.key) && !_pristine.contains(entry.key)) {
        continue;
      }
      _state[entry.key] = _evaluator().evaluate(entry.value, const {});
      _pristine.add(entry.key);
    }
  }

  void _setVar(String name, Object? value) {
    if (!mounted || _state[name] == value) return;
    _pristine.remove(name);
    setState(() {
      _state[name] = value;
      _stateVersion++;
    });
    _emit();
  }

  OpenUiFormController _form(String name) => _forms.putIfAbsent(
    name,
    () => OpenUiFormController(name)..addListener(_emit),
  );

  /// Every form's values, then the fields outside any form; a later field
  /// of the same name replaces an earlier one.
  List<(String, Object?)> _allChoices() => _merge([
    for (final f in _forms.entries)
      if (f.key.isNotEmpty) ...f.value.entries,
    ...?_forms['']?.entries,
  ]);

  /// [entries] with a later field replacing an earlier one of the same name.
  static List<(String, Object?)> _merge(List<(String, Object?)> entries) {
    final merged = <String, Object?>{};
    for (final (name, value) in entries) {
      merged.remove(name);
      merged[name] = value;
    }
    return [for (final e in merged.entries) (e.key, e.value)];
  }

  void _run(
    OpenUiAction action, {
    OpenUiFormController? form,
    bool validate = true,
  }) {
    // A submit with invalid fields shows their errors before anything runs
    // (upstream validates first, and only for primary buttons).
    if (form != null &&
        validate &&
        action.steps.any((s) => s.name == 'ToAssistant') &&
        !form.validate()) {
      return;
    }
    final evaluator = _evaluator();
    var changed = false;
    for (final step in action.steps) {
      Object? arg(int i) => i < step.args.length
          ? evaluator.evaluate(step.args[i], step.locals)
          : null;
      final target = step.args.isNotEmpty ? step.args.first : null;
      switch (step.name) {
        case 'ToAssistant':
          // The user's choices always ride along: a button in a Form sends
          // that form plus any choices made outside every form; any other
          // button sends every choice on screen, like upstream's snapshot.
          final submission = OpenUiSubmission(
            formName: form?.name,
            values: form == null
                ? _allChoices()
                : _merge([...form.entries, ...?_forms['']?.entries]),
            context: action.context,
          );
          final text = widget
              .formatSubmission(openUiToText(arg(0)).trim(), submission)
              .trim();
          if (text.isNotEmpty) widget.onSendPrompt?.call(text);
        case 'OpenUrl':
          final uri = Uri.tryParse(openUiToText(arg(0)));
          if (uri == null) break;
          final open = widget.onOpenUrl;
          if (open != null) {
            open(uri);
          } else {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        case 'Set':
          if (target is StateNode) {
            _state[target.name] = arg(1);
            _pristine.remove(target.name);
            changed = true;
          }
        case 'Reset':
          for (final node in step.args) {
            if (node is! StateNode) continue;
            final initial = _program.statements[node.name];
            _state[node.name] = initial == null
                ? null
                : evaluator.evaluate(initial, const {});
            _pristine.add(node.name);
            changed = true;
          }
      }
    }
    if (changed && mounted) {
      setState(() => _stateVersion++);
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final root = OpenUiEvaluator(
      _program,
      Map.of(_state),
      signatures: _library.signatures,
    ).evaluateRoot();
    if (root == null) return const SizedBox.shrink();
    Widget child = OpenUiScope(
      library: _library,
      isStreaming: _streaming,
      runAction: _run,
      setVar: _setVar,
      readVar: (name) => _state[name],
      form: _form,
      stateVersion: _stateVersion,
      child: OpenUiBlock(root),
    );
    final theme = widget.theme;
    if (theme != null) child = OpenUiTheme(data: theme, child: child);
    return child;
  }
}

/// What components need from the [OpenUiView] they render in.
class OpenUiScope extends InheritedWidget {
  const OpenUiScope({
    super.key,
    required this.library,
    required this.isStreaming,
    required this.runAction,
    required this.setVar,
    required this.readVar,
    required this.form,
    this.stateVersion = 0,
    required super.child,
  });

  final OpenUiLibrary library;
  final bool isStreaming;

  /// Runs an action's steps; [form] is the `Form` the trigger sits in and
  /// [validate] whether it must pass validation first (primary submits).
  final void Function(
    OpenUiAction action, {
    OpenUiFormController? form,
    bool validate,
  })
  runAction;

  /// Writes `$name` (or any view-level key) and rebuilds.
  final void Function(String name, Object? value) setVar;
  final Object? Function(String name) readVar;

  /// The controller holding the named form's values; created on first use
  /// and kept for the view's lifetime.
  final OpenUiFormController Function(String name) form;

  /// Changes whenever the view's state does.
  final int stateVersion;

  static OpenUiScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OpenUiScope>();
    assert(scope != null, 'openui components must render inside OpenUiView');
    return scope!;
  }

  @override
  bool updateShouldNotify(OpenUiScope old) =>
      isStreaming != old.isStreaming ||
      library != old.library ||
      stateVersion != old.stateVersion;
}
