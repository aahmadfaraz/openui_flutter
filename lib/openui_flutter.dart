/// Render OpenUI Lang — the generative UI language from OpenUI — as native
/// Flutter widgets.
///
/// ```dart
/// final split = splitOpenUi(answer, isStreaming: streaming);
/// Column(children: [
///   if (split.before.isNotEmpty) MyMarkdown(split.before),
///   if (split.hasProgram)
///     OpenUiView(
///       program: split.program!,
///       isStreaming: streaming,
///       onSendPrompt: sendMessage,
///     ),
/// ]);
/// ```
library;

export 'src/icons/icons.dart' show openUiIcon;
export 'src/lang.dart';
export 'src/library.dart';
export 'src/plain_text.dart';
export 'src/split.dart';
export 'src/theme.dart';
export 'src/view.dart';
export 'src/widgets/cards.dart';
export 'src/widgets/charts.dart';
export 'src/widgets/common.dart';
export 'src/widgets/content.dart';
export 'src/widgets/data.dart';
export 'src/widgets/forms.dart';
export 'src/widgets/layout.dart';
export 'src/widgets/markdown.dart';
