## 0.1.0

- First release: openui-lang parser and streaming evaluator (`$state`,
  `@Each`/`@Filter`/`@Sort`/aggregates, `Action([@ToAssistant, @OpenUrl,
  @Set, @Reset])`), `splitOpenUi` for prose + program answers, and native
  widgets for the OpenUI chat library: layout, content, tables, charts, forms,
  card blocks, icons (Lucide) and follow-ups.
- Form choices ride along with `@ToAssistant` as `My choices: …`.
- `OpenUiSnapshot` to keep a view's state across rebuilds.
- `OpenUiLibrary.extend` for custom components; `OpenUiThemeData` with
  markdown and image builder hooks.
