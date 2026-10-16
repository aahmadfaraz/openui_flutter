import 'package:flutter/widgets.dart';

import 'lang.dart';
import 'widgets/cards.dart';
import 'widgets/charts.dart';
import 'widgets/content.dart';
import 'widgets/data.dart';
import 'widgets/forms.dart';
import 'widgets/layout.dart';

/// Builds the widget for one evaluated component.
typedef OpenUiWidgetBuilder =
    Widget Function(BuildContext context, OpenUiElement element);

/// One openui-lang component: its name, its positional parameters (the order
/// the system prompt documents — this is what binds args to props) and how
/// it renders.
class OpenUiComponent {
  const OpenUiComponent(
    this.name,
    this.params, {
    this.builder,
    this.inline = false,
  });

  final String name;
  final List<String> params;

  /// Null for data-only components a parent reads (`Series`, `TabItem`,
  /// `SelectItem`…); rendered on their own they fall back to their text.
  final OpenUiWidgetBuilder? builder;

  /// Sizes to its content and sits inline in a row (buttons, tags), rather
  /// than taking a grid column like a card or chart.
  final bool inline;
}

/// The set of components a program may use. Start from [standard] and
/// [extend] it with your own; a later component replaces an earlier one of
/// the same name.
class OpenUiLibrary {
  OpenUiLibrary(Iterable<OpenUiComponent> components)
    : components = {for (final c in components) c.name: c};

  final Map<String, OpenUiComponent> components;

  late final Map<String, List<String>> signatures = {
    for (final c in components.values) c.name: c.params,
  };

  OpenUiLibrary extend(Iterable<OpenUiComponent> more) =>
      OpenUiLibrary([...components.values, ...more]);

  /// Every component of the OpenUI chat library.
  static final OpenUiLibrary standard = OpenUiLibrary(standardComponents);
}

Widget Function(BuildContext, OpenUiElement) _w(
  Widget Function(OpenUiElement el) build,
) =>
    (_, el) => build(el);

/// The OpenUI chat library: layout, content, tables, charts, forms,
/// buttons, data display and card blocks.
final List<OpenUiComponent> standardComponents = [
  // Layout
  OpenUiComponent('Stack', const [
    'children',
    'direction',
    'gap',
    'align',
    'justify',
    'wrap',
  ], builder: _w(OpenUiFlex.new)),
  OpenUiComponent('Tabs', const ['items'], builder: _w(OpenUiTabs.new)),
  const OpenUiComponent('TabItem', ['value', 'trigger', 'content']),
  OpenUiComponent('Accordion', const [
    'items',
  ], builder: _w(OpenUiAccordion.new)),
  const OpenUiComponent('AccordionItem', ['value', 'trigger', 'content']),
  OpenUiComponent('SectionBlock', const [
    'sections',
    'isFoldable',
  ], builder: _w(OpenUiSectionBlock.new)),
  const OpenUiComponent('SectionItem', ['value', 'trigger', 'content']),
  OpenUiComponent('FollowUpBlock', const [
    'items',
  ], builder: _w(OpenUiFollowUps.new)),
  const OpenUiComponent('FollowUpItem', ['text']),
  OpenUiComponent('Steps', const ['items'], builder: _w(OpenUiSteps.new)),
  const OpenUiComponent('StepsItem', ['title', 'details']),
  OpenUiComponent('Carousel', const [
    'children',
    'variant',
  ], builder: _w(OpenUiCarousel.new)),
  OpenUiComponent('Separator', const [
    'orientation',
    'decorative',
  ], builder: _w(OpenUiSeparator.new)),
  OpenUiComponent('Modal', const [
    'title',
    'open',
    'children',
    'size',
  ], builder: _w(OpenUiModal.new)),

  // Content
  OpenUiComponent('Card', const [
    'children',
    'variant',
    'direction',
    'gap',
    'align',
    'justify',
    'wrap',
  ], builder: _w(OpenUiCard.new)),
  OpenUiComponent('CardHeader', const [
    'title',
    'subtitle',
  ], builder: _w(OpenUiCardHeader.new)),
  OpenUiComponent('TextContent', const [
    'text',
    'size',
  ], builder: _w(OpenUiTextContent.new)),
  OpenUiComponent('MarkDownRenderer', const [
    'textMarkdown',
    'variant',
  ], builder: _w(OpenUiMarkdownBlock.new)),
  OpenUiComponent('Callout', const [
    'variant',
    'title',
    'description',
    'visible',
  ], builder: _w(OpenUiCallout.new)),
  OpenUiComponent('TextCallout', const [
    'variant',
    'title',
    'description',
  ], builder: _w(OpenUiCallout.new)),
  OpenUiComponent('Image', const ['alt', 'src'], builder: _w(OpenUiImage.new)),
  OpenUiComponent('ImageBlock', const [
    'src',
    'alt',
  ], builder: _w(OpenUiImage.new)),
  OpenUiComponent('ImageGallery', const [
    'images',
  ], builder: _w(OpenUiGallery.new)),
  OpenUiComponent('CodeBlock', const [
    'language',
    'codeString',
  ], builder: _w(OpenUiCode.new)),
  OpenUiComponent('InlineHeader', const [
    'heading',
    'description',
  ], builder: _w(OpenUiInlineHeader.new)),

  // Tables
  OpenUiComponent('Table', const ['columns'], builder: _w(OpenUiTable.new)),
  const OpenUiComponent('Col', ['label', 'data', 'type']),
  OpenUiComponent('EditableTable', const [
    'name',
    'columns',
    'data',
  ], builder: _w(OpenUiEditableTable.new)),

  // Charts
  for (final name in ['BarChart', 'LineChart', 'AreaChart'])
    OpenUiComponent(name, const [
      'labels',
      'series',
      'variant',
      'xLabel',
      'yLabel',
      'height',
    ], builder: _w(OpenUiChart.new)),
  OpenUiComponent('RadarChart', const [
    'labels',
    'series',
  ], builder: _w(OpenUiChart.new)),
  OpenUiComponent('HorizontalBarChart', const [
    'labels',
    'series',
    'variant',
    'xLabel',
    'yLabel',
  ], builder: _w(OpenUiChart.new)),
  const OpenUiComponent('Series', ['category', 'values']),
  OpenUiComponent('PieChart', const [
    'labels',
    'values',
    'variant',
    'appearance',
  ], builder: _w(OpenUiChart.new)),
  for (final name in ['RadialChart', 'SingleStackedBarChart'])
    OpenUiComponent(name, const [
      'labels',
      'values',
    ], builder: _w(OpenUiChart.new)),
  const OpenUiComponent('Slice', ['category', 'value']),
  OpenUiComponent('ScatterChart', const [
    'datasets',
    'xLabel',
    'yLabel',
  ], builder: _w(OpenUiChart.new)),
  const OpenUiComponent('ScatterSeries', ['name', 'points']),
  const OpenUiComponent('Point', ['x', 'y', 'z']),

  // Forms
  OpenUiComponent('Form', const [
    'name',
    'buttons',
    'fields',
  ], builder: _w(OpenUiForm.new)),
  OpenUiComponent('FormControl', const [
    'label',
    'input',
    'hint',
  ], builder: _w(OpenUiFormControl.new)),
  OpenUiComponent(
    'Label',
    const ['text'],
    builder: _w(OpenUiLabel.new),
    inline: true,
  ),
  OpenUiComponent('Input', const [
    'name',
    'placeholder',
    'type',
    'rules',
    'value',
  ], builder: _w(OpenUiTextInput.new)),
  OpenUiComponent('TextArea', const [
    'name',
    'placeholder',
    'rows',
    'rules',
    'value',
  ], builder: _w(OpenUiTextInput.new)),
  OpenUiComponent('Select', const [
    'name',
    'items',
    'placeholder',
    'rules',
    'value',
    'size',
  ], builder: _w(OpenUiSelect.new)),
  const OpenUiComponent('SelectItem', ['value', 'label']),
  OpenUiComponent('DatePicker', const [
    'name',
    'mode',
    'rules',
    'value',
  ], builder: _w(OpenUiDatePicker.new)),
  OpenUiComponent('Slider', const [
    'name',
    'variant',
    'min',
    'max',
    'step',
    'defaultValue',
    'label',
    'rules',
    'value',
  ], builder: _w(OpenUiSliderField.new)),
  OpenUiComponent('CheckBoxGroup', const [
    'name',
    'items',
    'rules',
    'value',
  ], builder: _w(OpenUiToggleGroup.new)),
  const OpenUiComponent('CheckBoxItem', [
    'label',
    'description',
    'name',
    'defaultChecked',
  ]),
  OpenUiComponent('RadioGroup', const [
    'name',
    'items',
    'defaultValue',
    'rules',
    'value',
  ], builder: _w(OpenUiRadioGroup.new)),
  const OpenUiComponent('RadioItem', ['label', 'description', 'value']),
  OpenUiComponent('SwitchGroup', const [
    'name',
    'items',
    'variant',
    'value',
  ], builder: _w(OpenUiToggleGroup.new)),
  const OpenUiComponent('SwitchItem', [
    'label',
    'description',
    'name',
    'defaultChecked',
  ]),
  OpenUiComponent('Chips', const [
    'name',
    'type',
    'items',
    'rules',
    'defaultValue',
  ], builder: _w(OpenUiChoiceGroup.new)),
  const OpenUiComponent('ChipItem', ['value', 'label', 'icon', 'disabled']),
  OpenUiComponent('OptionCards', const [
    'name',
    'type',
    'items',
    'rules',
    'defaultValue',
  ], builder: _w(OpenUiChoiceGroup.new)),
  const OpenUiComponent('OptionCard', [
    'value',
    'title',
    'subtitle',
    'topContent',
    'disabled',
  ]),

  // Buttons
  OpenUiComponent(
    'Button',
    const ['label', 'action', 'variant', 'type', 'size'],
    builder: _w(OpenUiButton.new),
    inline: true,
  ),
  OpenUiComponent(
    'Buttons',
    const ['buttons', 'direction'],
    builder: _w(OpenUiButtons.new),
    inline: true,
  ),
  OpenUiComponent(
    'IconButton',
    const ['name', 'icon', 'action', 'variant', 'size', 'shape'],
    builder: _w(OpenUiIconButton.new),
    inline: true,
  ),

  // Data display
  OpenUiComponent(
    'TagBlock',
    const ['tags', 'size'],
    builder: _w(OpenUiTagBlock.new),
    inline: true,
  ),
  OpenUiComponent(
    'Tag',
    const ['text', 'icon', 'size', 'variant'],
    builder: _w(OpenUiTagComponent.new),
    inline: true,
  ),
  OpenUiComponent(
    'Icon',
    const ['name', 'category'],
    builder: _w(OpenUiIconComponent.new),
    inline: true,
  ),
  OpenUiComponent('EntityList', const [
    'rows',
    'size',
    'header',
    'footer',
  ], builder: _w(OpenUiEntityList.new)),
  OpenUiComponent('ListBlock', const [
    'items',
    'variant',
    'size',
  ], builder: _w(OpenUiListBlock.new)),
  const OpenUiComponent('ListItem', [
    'title',
    'subtitle',
    'image',
    'actionLabel',
    'action',
  ]),

  // Card blocks
  for (final name in [
    'SnippetCardBlock',
    'OverviewCardBlock',
    'ContextCardBlock',
    'CompositeCardBlock',
    'VisualCardBlock',
  ])
    OpenUiComponent(name, const [
      'items',
      'layout',
      'responsive',
      'action',
      'gap',
    ], builder: _w(OpenUiCardBlock.new)),
  OpenUiComponent('SnippetCardItem', const [
    'id',
    'lhs',
    'rhs',
  ], builder: _w(OpenUiCardItem.new)),
  OpenUiComponent('OverviewCardItem', const [
    'id',
    'top',
    'bottom',
  ], builder: _w(OpenUiCardItem.new)),
  OpenUiComponent('ContextCardItem', const [
    'id',
    'title',
    'body',
    'bgColor',
    'bgImageSrc',
    'bgImageAlt',
  ], builder: _w(OpenUiCardItem.new)),
  OpenUiComponent('CompositeCardItem', const [
    'id',
    'header',
    'body',
    'footer',
  ], builder: _w(OpenUiCardItem.new)),
  OpenUiComponent('VisualCardItem', const [
    'body',
    'id',
    'bgImageSrc',
    'tag',
    'bgImageAlt',
  ], builder: _w(OpenUiCardItem.new)),
  for (final name in ['Text', 'BoldText'])
    OpenUiComponent(
      name,
      const ['variant', 'value', 'subtext', 'subtextVariant', 'size'],
      builder: _w(OpenUiTextLine.new),
      inline: true,
    ),
  OpenUiComponent('IconText', const [
    'icon',
    'iconVariant',
    'iconSize',
    'title',
    'subtitle',
    'bold',
    'layout',
  ], builder: _w(OpenUiIconText.new)),
  OpenUiComponent('ImageText', const [
    'src',
    'alt',
    'title',
    'subtitle',
    'bold',
    'layout',
    'imageSize',
  ], builder: _w(OpenUiImageText.new)),
  OpenUiComponent('ImageTextLarge', const [
    'src',
    'alt',
    'title',
    'subtitle',
    'bold',
  ], builder: _w(OpenUiImageText.new)),
  OpenUiComponent('MetricIndicatorInline', const [
    'value',
    'subtext',
    'trend',
  ], builder: _w(OpenUiMetric.new)),
  OpenUiComponent('MetricIndicatorWithStrikethrough', const [
    'value',
    'subtext',
    'previousValue',
    'trend',
  ], builder: _w(OpenUiMetric.new)),
];
