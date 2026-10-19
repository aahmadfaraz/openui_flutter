## 0.1.3

- Fix: build failed with flutter_lucide 1.59 ("Member not found: 'music'"),
  which renamed the music icons. Icon names regenerated from 1.59, the old
  `music*` names kept as aliases, and flutter_lucide pinned to 1.59.x since
  it renames icons in minor releases.

## 0.1.2

- LICENSE names the copyright holder (Ahmad Faraz).

## 0.1.1

- Shorter package description, within pub.dev's 180-character limit.

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
