import 'package:flutter/material.dart';
import 'package:openui_flutter/openui_flutter.dart';

/// An assistant answer: a lead sentence, then an openui-lang program.
const answer = r'''
Here's a quick plan. Pick what suits you:

root = Stack([title, form])
title = TextContent("Weekend in Lisbon", "large-heavy")
form = Form("trip", [go], [pace, interests])
pace = FormControl("Pace", RadioGroup("pace", [RadioItem("Relaxed", "Slow mornings", "relaxed"), RadioItem("Packed", "See it all", "packed")], "relaxed"))
interests = FormControl("Interests", Chips("interests", "multiple", [ChipItem("food", "Food"), ChipItem("views", "Views"), ChipItem("history", "History")]))
go = Button("Plan my weekend", Action([@ToAssistant("Plan my Lisbon weekend")]), "primary")
''';

void main() => runApp(
  MaterialApp(
    theme: ThemeData.dark(),
    home: const Scaffold(body: SafeArea(child: AnswerView(answer))),
  ),
);

class AnswerView extends StatelessWidget {
  const AnswerView(this.answer, {super.key, this.isStreaming = false});

  final String answer;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    // Prose before/after the program renders as markdown; the program as
    // native widgets.
    final split = splitOpenUi(answer, isStreaming: isStreaming);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (split.before.trim().isNotEmpty)
          OpenUiMarkdown(split.before, style: const TextStyle(fontSize: 15)),
        if (split.hasProgram)
          OpenUiView(
            program: split.program!,
            isStreaming: isStreaming,
            // "Plan my Lisbon weekend\n\nMy choices: pace: relaxed; ..."
            onSendPrompt: (text) => ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(text))),
          ),
      ],
    );
  }
}
