import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

import 'budget_fixture.dart';
import 'gym_fixture.dart';
import 'phones_fixture.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: child,
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  String program, {
  List<String>? sent,
  bool isStreaming = false,
}) async {
  await tester.pumpWidget(
    _host(
      OpenUiView(
        program: program,
        isStreaming: isStreaming,
        onSendPrompt: sent?.add,
      ),
    ),
  );
  await tester.pump();
  // A streaming view types its text out over a few frames.
  if (isStreaming) {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  // Phone-sized surface (iPhone 15: 390×844 @3x): overflows show up here,
  // not at the 800×600 default.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('renders the budget answer as native components', (tester) async {
    final sent = <String>[];
    await _pump(tester, splitOpenUi(budgetAnswer).program!, sent: sent);
    expect(tester.takeException(), isNull);
    expect(find.text('Where the money goes'), findsOneWidget);
    expect(find.text('Not overspending'), findsOneWidget);
    expect(find.text('Transport (bus pass)'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    await _tap(tester, find.text('Make a weekly plan'));
    expect(sent, [
      'Turn this monthly budget into a weekly spending plan in GBP.',
    ]);
  });

  testWidgets('renders the phone comparison; OpenUrl goes to the host', (
    tester,
  ) async {
    final sent = <String>[];
    final opened = <Uri>[];
    await tester.pumpWidget(
      _host(
        OpenUiView(
          program: splitOpenUi(phonesAnswer).program!,
          onSendPrompt: sent.add,
          onOpenUrl: opened.add,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final text in [
      'Galaxy S26 Ultra',
      'A19 Pro',
      r'$1,399.99',
      'Outstanding cameras',
      'Raw Numbers',
      'Setup note',
      'Pick your ecosystem',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    await _tap(tester, find.text('Galaxy deal'));
    expect(sent, ['Tell me more about the Galaxy S26 Ultra']);
    await _tap(tester, find.text('Read Pixel vs iPhone'));
    expect(opened.single.host, 'www.phonearena.com');
  });

  test('a program copies as readable text', () {
    final text = openUiToPlainText(splitOpenUi(budgetAnswer).program!);
    expect(text, contains('Semester monthly budget'));
    expect(text, contains('Rent: 620'));
    expect(text, contains('Total: 1420'));
    expect(text, isNot(contains('root =')));
    final phones = openUiToPlainText(splitOpenUi(phonesAnswer).program!);
    expect(phones, contains('Model | Display | Chip | Current deal'));
    expect(phones, contains('iPhone 17 Pro: Cameras 9, Performance 8'));
  });

  testWidgets('components ease in while streaming, not from history', (
    tester,
  ) async {
    await _pump(tester, 'root = TextContent("Hi")', isStreaming: true);
    expect(
      find.descendant(
        of: find.byType(OpenUiAppear),
        matching: find.byType(Opacity),
      ),
      findsWidgets,
    );
    await _pump(tester, 'root = TextContent("Bye")');
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, 'root = TextContent("Again")');
    expect(
      find.descendant(
        of: find.byType(OpenUiAppear),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('buttons stay inert while the answer streams', (tester) async {
    final sent = <String>[];
    await _pump(
      tester,
      'root = Buttons([b])\nb = Button("Go")',
      sent: sent,
      isStreaming: true,
    );
    await tester.tap(find.text('Go'));
    expect(sent, isEmpty);
  });

  testWidgets('@Set updates state and the UI', (tester) async {
    await _pump(
      tester,
      '\$n = 0\n'
      'root = Stack([t, b])\n'
      't = TextContent("Count: " + \$n)\n'
      'b = Button("Add", Action([@Set(\$n, \$n + 1)]))',
    );
    await _tap(tester, find.text('Add'));
    expect(find.textContaining('Count: 1'), findsOneWidget);
  });

  group('forms', () {
    testWidgets('the gym form submits its choices in display order', (
      tester,
    ) async {
      final sent = <String>[];
      await _pump(tester, splitOpenUi(gymAnswer).program!, sent: sent);
      expect(tester.takeException(), isNull);
      expect(find.text('Lose fat'), findsOneWidget);
      expect(find.byIcon(LucideIcons.flame), findsOneWidget);

      // goal is required and has no default: the submit is blocked.
      await _tap(tester, find.text('Build my routine'));
      expect(sent, isEmpty);
      expect(find.text('This field is required'), findsOneWidget);

      await _tap(tester, find.text('Lose fat'));
      await _tap(tester, find.text('Intermediate'));
      await _tap(tester, find.text('Dumbbells'));
      await _tap(tester, find.text('Build my routine'));
      expect(sent, [
        'Build my gym routine based on my choices\n\n'
            'My choices: goal: fat-loss; experience: intermediate; days: 3; '
            'time: morning; equipment: bodyweight, dumbbells.',
      ]);
    });

    testWidgets('inputs validate their rules', (tester) async {
      final sent = <String>[];
      await _pump(
        tester,
        'root = Form("c", Buttons([Button("Send")]), [f])\n'
        'f = FormControl("Email", Input("email", "you@x.com", "email", {required: true, email: true}))',
        sent: sent,
      );
      await tester.enterText(find.byType(TextField), 'nope');
      await _tap(tester, find.text('Send'));
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(sent, isEmpty);

      await tester.enterText(find.byType(TextField), 'a@b.co');
      await _tap(tester, find.text('Send'));
      expect(sent, ['Send\n\nMy choices: email: a@b.co.']);
    });

    testWidgets('checkbox groups submit their checked items', (tester) async {
      final sent = <String>[];
      await _pump(
        tester,
        'root = Form("p", Buttons([Button("Go")]), [f])\n'
        'f = FormControl("Interests", CheckBoxGroup("interests", [CheckBoxItem("Landmarks", "", "landmarks", true), CheckBoxItem("Food", "", "food")]))',
        sent: sent,
      );
      await _tap(tester, find.text('Food'));
      await _tap(tester, find.text('Go'));
      expect(sent, ['Go\n\nMy choices: interests: landmarks, food.']);
    });

    testWidgets('a button outside the form still sends the choices', (
      tester,
    ) async {
      final sent = <String>[];
      await _pump(
        tester,
        'root = Stack([prefs, go])\n'
        'prefs = Chips("pace", "single", [ChipItem("slow", "Slow"), ChipItem("fast", "Fast")], null, "slow")\n'
        'go = Buttons([Button("Make my trip")])',
        sent: sent,
      );
      await _tap(tester, find.text('Fast'));
      await _tap(tester, find.text('Make my trip'));
      expect(sent, ['Make my trip\n\nMy choices: pace: fast.']);
    });

    testWidgets('a field bound to \$state drives a filter', (tester) async {
      await _pump(
        tester,
        '\$q = ""\n'
        'root = Stack([search, list])\n'
        'search = Input("q", "Search", "text", null, \$q)\n'
        'list = TagBlock(@Filter(rows, "name", "contains", \$q).name)\n'
        'rows = [{name: "Apple"}, {name: "Banana"}, {name: "Cherry"}]',
      );
      expect(find.text('Banana'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'an');
      await tester.pump();
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
    });
  });

  group('card blocks', () {
    testWidgets('composite cards render header, metric, tags and footer', (
      tester,
    ) async {
      final sent = <String>[];
      await _pump(
        tester,
        'root = Stack([cards])\n'
        'cards = CompositeCardBlock([p1, p2])\n'
        'p1 = CompositeCardItem("a", IconText(Icon("package"), "neutral", "m", "Widget Pro", "Best seller"), [MetricIndicatorInline("2,410 units", "Sold", {direction: "up", value: 12}), TagBlock(["Free shipping"], "sm")], {price: MetricIndicatorWithStrikethrough("\$29", "Sale", "\$35"), button: Button("View", Action([@ToAssistant("Show Widget Pro")]), "secondary")})\n'
        'p2 = CompositeCardItem("b", IconText(Icon("box"), "neutral", "m", "Widget Mini"), [], {button: Button("View mini")})',
        sent: sent,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Widget Pro'), findsOneWidget);
      expect(find.text('2,410 units'), findsOneWidget);
      expect(find.text('▲ 12%'), findsOneWidget);
      expect(find.text('\$35'), findsOneWidget);
      expect(find.text('Free shipping'), findsOneWidget);
      await _tap(tester, find.text('View'));
      expect(sent, ['Show Widget Pro']);
    });

    testWidgets('a block action names the tapped card', (tester) async {
      final sent = <String>[];
      await _pump(
        tester,
        'root = ContextCardBlock([a, b], "grid", true, Action([@ToAssistant("Tell me more")]))\n'
        'a = ContextCardItem("a", Tag("Pro", null, "sm", "success"), "Fast and light")\n'
        'b = ContextCardItem("b", "Con", "Pricey")',
        sent: sent,
      );
      await _tap(tester, find.text('Pricey'));
      expect(sent, [
        'Tell me more\n\nSelected item: '
            '{"itemIndex":1,"itemId":"b","itemTitle":"Con","itemBody":"Pricey"}',
      ]);
    });

    testWidgets('overview, snippet and visual blocks render', (tester) async {
      await _pump(
        tester,
        'root = Stack([o, s, v])\n'
        'o = OverviewCardBlock([OverviewCardItem("r", IconText(Icon("circle-dollar-sign"), "success", "m", "Revenue"), MetricIndicatorInline("\$48k")), OverviewCardItem("u", Text("text", "Users"), MetricIndicatorInline("1,204"))])\n'
        's = SnippetCardBlock([SnippetCardItem("w", IconText(Icon("wifi"), "neutral", "m", "Wi-Fi"), BoldText("text", "Free")), SnippetCardItem("p", IconText(Icon("car"), "neutral", "m", "Parking"), Text("text", "€10"))])\n'
        'v = VisualCardBlock([VisualCardItem(BoldText("text", "Kyoto", "Temples"), "k", "", Tag("Culture", null, "sm", "info")), VisualCardItem(BoldText("text", "Osaka"), "o", "")])',
      );
      expect(tester.takeException(), isNull);
      for (final text in [
        'Revenue',
        '\$48k',
        'Wi-Fi',
        'Free',
        'Kyoto',
        'Temples',
        'Culture',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });
  });

  testWidgets('tabs, accordion, steps, carousel and table render', (
    tester,
  ) async {
    await _pump(
      tester,
      'root = Stack([tabs, faq, steps, car, tbl])\n'
      'tabs = Tabs([TabItem("a", "Alpha", [TextContent("In alpha")]), TabItem("b", "Beta", [TextContent("In beta")])])\n'
      'faq = Accordion([AccordionItem("q", "Why?", [TextContent("Because")])])\n'
      'steps = Steps([StepsItem("Install", "Run it"), StepsItem("Use", "Enjoy")])\n'
      'car = Carousel([[CardHeader("Slide one")], [CardHeader("Slide two")]], "card")\n'
      'tbl = Table([Col("Name", ["Ann", "Bo"]), Col("Score", [9, 7], "number")])',
    );
    expect(tester.takeException(), isNull);
    expect(find.text('In alpha'), findsOneWidget);
    await _tap(tester, find.text('Beta'));
    expect(find.text('In beta'), findsOneWidget);
    expect(find.text('Because'), findsNothing);
    await _tap(tester, find.text('Why?'));
    await tester.pumpAndSettle();
    expect(find.text('Because'), findsOneWidget);
    for (final text in ['Install', 'Slide two', 'Bo', '9']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('section blocks and follow-ups', (tester) async {
    final sent = <String>[];
    await _pump(
      tester,
      'root = Stack([sec, fu])\n'
      'sec = SectionBlock([SectionItem("a", "Overview", [TextContent("Inside")])])\n'
      'fu = FollowUpBlock([FollowUpItem("What next?")])',
      sent: sent,
    );
    expect(find.text('Inside'), findsOneWidget);
    await _tap(tester, find.text('What next?'));
    expect(sent, ['What next?']);
  });

  testWidgets('a bound Modal opens while its state is true', (tester) async {
    await _pump(
      tester,
      '\$open = false\n'
      'root = Stack([b, m])\n'
      'b = Buttons([Button("Edit", Action([@Set(\$open, true)]))])\n'
      'm = Modal("Edit item", \$open, [TextContent("Modal body")])',
    );
    expect(find.text('Modal body'), findsNothing);
    await _tap(tester, find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Modal body'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Modal body'), findsNothing);
  });

  testWidgets('all chart types render without errors', (tester) async {
    await _pump(
      tester,
      'root = Stack([a, b, c, d, e, f, g, h, i])\n'
      'l = ["A", "B", "C"]\n'
      's = [Series("One", [1, 2, 3]), Series("Two", [3, 2, 1])]\n'
      'a = BarChart(l, s, "stacked")\n'
      'b = HorizontalBarChart(l, s)\n'
      'c = LineChart(l, s, "natural")\n'
      'd = AreaChart(l, s)\n'
      'e = RadarChart(l, s)\n'
      'f = PieChart(l, [1, 2, 3], "donut", "semiCircular")\n'
      'g = RadialChart(l, [1, 2, 3])\n'
      'h = SingleStackedBarChart(l, [1, 2, 3])\n'
      'i = ScatterChart([ScatterSeries("S", [Point(1, 2), Point(2, 3, 5)])], "x", "y")',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown components degrade to their text', (tester) async {
    await _pump(
      tester,
      'root = Stack([b])\n'
      'b = FancyWidget(Thing("Widget Pro"))',
    );
    expect(find.text('Widget Pro'), findsNothing);
    await _pump(
      tester,
      'root = Stack([b])\n'
      'b = TravelGallery([TravelImage("", "A photo")])',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom component extends the library', (tester) async {
    final library = OpenUiLibrary.standard.extend([
      OpenUiComponent('Hello', const [
        'name',
      ], builder: (context, el) => Text('Hi ${el.string('name')}')),
    ]);
    await tester.pumpWidget(
      _host(OpenUiView(program: 'root = Hello("Ada")', library: library)),
    );
    expect(find.text('Hi Ada'), findsOneWidget);
  });

  test('icons resolve by lucide name, old names and category', () {
    expect(openUiIcon('circle-check'), LucideIcons.circle_check);
    expect(openUiIcon('check-circle'), LucideIcons.circle_check);
    expect(openUiIcon('building-2'), LucideIcons.building);
    expect(
      openUiIcon('no-such-icon', category: 'fitness'),
      LucideIcons.dumbbell,
    );
  });

  group('streaming performance', () {
    testWidgets('unchanged components are not rebuilt as the program grows', (
      tester,
    ) async {
      var builds = 0;
      final library = OpenUiLibrary.standard.extend([
        OpenUiComponent(
          'Probe',
          const ['label'],
          builder: (context, el) {
            builds++;
            return Text(el.string('label') ?? '');
          },
        ),
      ]);
      Future<void> pump(String program) => tester.pumpWidget(
        _host(
          OpenUiView(
            program: program,
            library: library,
            isStreaming: true,
            smoothReveal: false,
          ),
        ),
      );
      await pump('root = Stack([a, b])\na = Probe("first")');
      expect(builds, 1);
      // More of the program streams in: `a` is unchanged, so not rebuilt.
      await pump('root = Stack([a, b])\na = Probe("first")\nb = Text("x")');
      await pump(
        'root = Stack([a, b])\na = Probe("first")\nb = Text("xyz more")',
      );
      expect(builds, 1);
      // `a` itself changes: rebuilt once.
      await pump('root = Stack([a, b])\na = Probe("second")\nb = Text("x")');
      expect(builds, 2);
      expect(find.text('second'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('state read straight off the scope still updates', (
      tester,
    ) async {
      final library = OpenUiLibrary.standard.extend([
        OpenUiComponent(
          'Counter',
          const [],
          builder: (context, el) {
            final scope = OpenUiScope.of(context);
            final n = (scope.readVar('__n') as int?) ?? 0;
            return TextButton(
              onPressed: () => scope.setVar('__n', n + 1),
              child: Text('count $n'),
            );
          },
        ),
      ]);
      await tester.pumpWidget(
        _host(OpenUiView(program: 'root = Counter()', library: library)),
      );
      await tester.tap(find.text('count 0'));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);
    });

    testWidgets('streamed text types out instead of landing at once', (
      tester,
    ) async {
      const text = 'The quick brown fox jumps over the lazy dog again';
      await tester.pumpWidget(
        _host(
          const OpenUiView(
            program: 'root = TextContent("$text")',
            isStreaming: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('The', findRichText: true),
        findsWidgets,
        reason: 'some text has typed in',
      );
      expect(
        find.text(text, findRichText: true),
        findsNothing,
        reason: 'but not all of it yet',
      );
      // Real frames (a single 2s pump is one frame, and the reveal never
      // dumps a backlog in one frame).
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text(text, findRichText: true), findsOneWidget);
    });

    test('openUiSame compares structure, not identity', () {
      OpenUiElement el(String label) => OpenUiElement('Text', {
        'text': label,
        'items': [1, 2, {'a': true}],
        'action': OpenUiAction.toAssistant('go'),
      });
      expect(openUiSame(el('x'), el('x')), isTrue);
      expect(openUiSame(el('x'), el('y')), isFalse);
      expect(
        openUiSame(
          OpenUiAction.toAssistant('go'),
          OpenUiAction.toAssistant('stop'),
        ),
        isFalse,
      );
    });
  });

  group('upstream parity', () {
    testWidgets('chips select many by default and ride along', (tester) async {
      final sent = <String>[];
      await _pump(
        tester,
        'root = Stack([chips, go])\n'
        'chips = Chips("cuisine", null, [ChipItem("thai", "Thai"), ChipItem("sushi", "Sushi")])\n'
        'go = Button("Find places")',
        sent: sent,
      );
      await _tap(tester, find.text('Thai'));
      await _tap(tester, find.text('Sushi'));
      await _tap(tester, find.text('Find places'));
      expect(sent, ['Find places\n\nMy choices: cuisine: thai, sushi.']);
    });

    testWidgets('a snapshot restores choices after a rebuild', (tester) async {
      const program =
          'root = Stack([chips, go])\n'
          'chips = Chips("cuisine", "single", [ChipItem("thai", "Thai"), ChipItem("sushi", "Sushi")])\n'
          'go = Button("Find places")';
      OpenUiSnapshot? saved;
      await tester.pumpWidget(
        _host(
          OpenUiView(
            key: const ValueKey(1),
            program: program,
            onStateChanged: (s) => saved = s,
          ),
        ),
      );
      await _tap(tester, find.text('Sushi'));
      expect(saved?.forms['']?['cuisine'], 'sushi');

      final sent = <String>[];
      await tester.pumpWidget(
        _host(
          OpenUiView(
            key: const ValueKey(2),
            program: program,
            initialState: saved,
            onSendPrompt: sent.add,
          ),
        ),
      );
      await tester.pump();
      await _tap(tester, find.text('Find places'));
      expect(sent, ['Find places\n\nMy choices: cuisine: sushi.']);
    });

    testWidgets('tables page ten rows at a time', (tester) async {
      final rows = [for (var i = 1; i <= 23; i++) '"Row $i"'].join(', ');
      await _pump(tester, 'root = Table([Col("Name", [$rows])])');
      expect(find.text('Row 10'), findsOneWidget);
      expect(find.text('Row 11'), findsNothing);
      expect(find.text('1 / 3'), findsOneWidget);
      await _tap(tester, find.byIcon(Icons.chevron_right_rounded));
      expect(find.text('Row 11'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('sections open as they stream, then fold to the first', (
      tester,
    ) async {
      const program =
          'root = SectionBlock([s1, s2])\n'
          's1 = SectionItem("a", "First", [TextContent("Alpha body")])\n'
          's2 = SectionItem("b", "Second", [TextContent("Beta body")])';
      await _pump(tester, program, isStreaming: true);
      await tester.pumpAndSettle();
      expect(find.text('Alpha body'), findsOneWidget);
      expect(find.text('Beta body'), findsOneWidget);

      await _pump(tester, program);
      await tester.pumpAndSettle();
      expect(find.text('Alpha body'), findsOneWidget);
      expect(find.text('Beta body'), findsNothing);
    });

    testWidgets('a modal\'s content stays live while open', (tester) async {
      Future<void> pumpWith(String note) => _pump(
        tester,
        '\$open = true\n'
        'root = Modal("Details", \$open, [TextContent("$note")])',
      );
      await pumpWith('Loading');
      await tester.pumpAndSettle();
      expect(find.text('Loading'), findsOneWidget);
      await pumpWith('Loaded');
      await tester.pumpAndSettle();
      expect(find.text('Loaded'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('galleries show five tiles and a +N count', (tester) async {
      final images = [
        for (var i = 0; i < 8; i++) '{src: "https://x.test/$i.jpg", alt: "P$i"}',
      ].join(', ');
      await _pump(tester, 'root = ImageGallery([$images])');
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('pie legends fold past six slices', (tester) async {
      final labels = [for (var i = 0; i < 9; i++) '"S$i"'].join(', ');
      final values = [for (var i = 0; i < 9; i++) '${i + 1}'].join(', ');
      await _pump(tester, 'root = PieChart([$labels], [$values])');
      expect(find.text('S7'), findsNothing);
      await _tap(tester, find.text('Show more (3)'));
      await tester.pumpAndSettle();
      expect(find.text('S7'), findsOneWidget);
    });

    testWidgets('pie charts take the legacy Slice list too', (tester) async {
      await _pump(
        tester,
        'root = PieChart([Slice("Housing", 700), Slice("Food", 400), Slice("Savings", 400)], "donut")',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Housing'), findsOneWidget);
      expect(find.text('700 · 47%'), findsOneWidget);
    });

    testWidgets('code blocks copy their source', (tester) async {
      await _pump(tester, 'root = CodeBlock("dart", "print(1);")');
      expect(find.text('print(1);'), findsOneWidget);
      await _tap(tester, find.byIcon(Icons.copy_rounded));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    test('every category fallback and renamed icon still resolves', () {
      // Guards the generated name map against flutter_lucide renames
      // (1.59 replaced music*): each must find a real icon, not the dot.
      const categories = [
        'accessibility', 'account', 'animals', 'arrows', 'brands',
        'buildings', 'charts', 'communication', 'connectivity', 'cursors',
        'design', 'development', 'devices', 'emoji', 'files', 'finance',
        'food-beverage', 'gaming', 'home', 'layout', 'mail', 'math',
        'medical', 'multimedia', 'nature', 'navigation', 'notifications',
        'people', 'photography', 'science', 'seasons', 'security', 'shapes',
        'shopping', 'social', 'sports', 'sustainability', 'text', 'time',
        'tools', 'transportation', 'travel', 'weather', 'music',
      ];
      for (final c in categories) {
        expect(
          openUiIcon('no-such-icon', category: c),
          isNot(LucideIcons.circle_dot),
          reason: c,
        );
      }
      for (final name in ['music', 'music-2', 'music-3', 'music-4', 'smile']) {
        expect(openUiIcon(name), isNot(LucideIcons.circle_dot), reason: name);
      }
    });

    test('icons follow upstream category fallbacks and renames', () {
      expect(openUiIcon('smile'), isNot(LucideIcons.circle_dot));
      expect(
        openUiIcon('nope', category: 'food-beverage'),
        LucideIcons.cooking_pot,
      );
    });
  });
}
