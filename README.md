# openui_flutter

Render [OpenUI](https://github.com/thesysdev/openui) **openui-lang** — the
streaming generative-UI language an LLM writes instead of markdown — as native
Flutter widgets.

An assistant answer like

```text
Here's how they compare.

root = Stack([title, table, more])
title = TextContent("Flagships", "large-heavy")
table = Table([Col("Model", ["iPhone 17 Pro", "Pixel 10 Pro"]), Col("Chip", ["A19 Pro", "Tensor G5"])])
more = Button("Compare cameras", Action([@ToAssistant("Compare their cameras")]))
```

renders as a heading, a real table and a button that sends the next message.

## Features

- **Streaming.** Re-parse on every chunk; unfinished statements are closed
  automatically and references to statements that haven't arrived yet render
  as nothing, so the UI grows smoothly as tokens land. New components ease in.
- **The OpenUI chat library**: Stack, Card, Tabs, Accordion, Steps,
  Carousel, SectionBlock, Modal, TextContent, Markdown, Callout, Image,
  ImageGallery, CodeBlock, Table, EntityList, ListBlock, TagBlock, the five
  card blocks, Bar/Line/Area/Radar/Pie/Radial/Scatter charts, Buttons,
  FollowUpBlock and every form control (Input, TextArea, Select, DatePicker,
  Slider, Checkbox/Radio/Switch/Toggle groups, Chips, OptionCards,
  EditableTable) with upstream validation rules and messages.
- **Interactivity.** `$state`, `@Set`/`@Reset`, `@OpenUrl`, and
  `@ToAssistant` — which sends the message *with the user's form choices*:

  ```text
  Build my routine

  My choices: goal: fat-loss; days: 3; equipment: dumbbells, bands.
  ```

- **Extensible.** Add your own components with `OpenUiLibrary.extend`.
- **Themeable.** `OpenUiThemeData` colours, font, radius, plus hooks for your
  app's markdown renderer and image loader.

## Usage

```dart
final split = splitOpenUi(answer, isStreaming: isStreaming);

Column(children: [
  if (split.before.isNotEmpty) MyMarkdown(split.before),
  if (split.hasProgram)
    OpenUiView(
      program: split.program!,
      isStreaming: isStreaming,
      onSendPrompt: (text) => chat.send(text),
    ),
  if (split.after.isNotEmpty) MyMarkdown(split.after),
]);
```

See [`example/example.dart`](example/example.dart).

### Custom components

```dart
final library = OpenUiLibrary.standard.extend([
  OpenUiComponent(
    'Weather',
    const ['city', 'tempC'],
    builder: (context, el) =>
        Text('${el.string('city')}: ${el.number('tempC')}°C'),
  ),
]);

OpenUiView(program: program, library: library);
```

Tell your model about the component in its openui-lang system prompt.

### Keeping state across rebuilds

In a chat list, rows are rebuilt as they scroll. Keep each answer's state:

```dart
OpenUiView(
  program: program,
  initialState: snapshots[messageId],
  onStateChanged: (s) => snapshots[messageId] = s,
);
```

### Copying an answer

`openUiToPlainText(program)` turns a program into readable text (tables as
rows, charts as values) for copy/share.

## Differences from the React renderer

- `@ToAssistant` submissions are formatted as text (`My choices: …`, and
  `Selected item: {…}` for card blocks); override with `formatSubmission`.
- Buttons, follow-ups and inputs are disabled while the answer streams.
- `Query`/`Mutation` tool calls (`Run`) aren't supported.

## License

MIT. Parts are ported from OpenUI by Thesys Inc. (MIT); see [LICENSE](LICENSE).
