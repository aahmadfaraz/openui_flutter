import 'package:flutter/material.dart';

/// Renders markdown [text] (TextContent, MarkDownRenderer, Callout bodies…)
/// in [style]. Plug in your app's markdown renderer; the default handles
/// headings, lists, bold/italic, inline code and links.
typedef OpenUiMarkdownBuilder =
    Widget Function(BuildContext context, String text, TextStyle style);

/// Loads a network image. Plug in a caching loader (e.g.
/// `cached_network_image`); the default is [Image.network].
typedef OpenUiImageBuilder =
    Widget Function(
      BuildContext context,
      String url, {
      BoxFit fit,
      double? width,
      double? height,
      Alignment alignment,
      Widget? placeholder,
    });

/// Colours, type and hooks the components draw with. Provide one through
/// [OpenUiTheme]; without it components derive one from the ambient
/// Material [Theme] via [OpenUiThemeData.fromTheme].
@immutable
class OpenUiThemeData {
  const OpenUiThemeData({
    required this.surface,
    required this.surfaceSunk,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textStrong,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.primaryBorder,
    required this.primaryText,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.chip,
    required this.chipBorder,
    required this.skeleton,
    this.chartPalette = defaultChartPalette,
    this.fontFamily,
    this.baseFontSize = 15,
    this.radius = 14,
    this.markdownBuilder,
    this.imageBuilder,
  });

  /// Derives every colour from a Material [ThemeData].
  factory OpenUiThemeData.fromTheme(ThemeData theme) {
    final s = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return OpenUiThemeData(
      surface: s.surfaceContainerLow,
      surfaceSunk: s.surfaceContainerHighest.withValues(alpha: .5),
      surfaceRaised: s.surfaceContainerHigh,
      border: s.outlineVariant,
      borderStrong: s.outline,
      textStrong: s.onSurface,
      text: s.onSurface.withValues(alpha: .9),
      textMuted: s.onSurfaceVariant,
      textFaint: s.onSurfaceVariant.withValues(alpha: .7),
      primary: s.primary,
      onPrimary: s.onPrimary,
      primarySoft: s.primary.withValues(alpha: .14),
      primaryBorder: s.primary.withValues(alpha: .4),
      primaryText: s.primary,
      success: dark ? const Color(0xFF34D399) : const Color(0xFF059669),
      warning: dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
      danger: s.error,
      info: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      chip: s.surfaceContainerHighest.withValues(alpha: .6),
      chipBorder: s.outlineVariant,
      skeleton: s.surfaceContainerHighest,
    );
  }

  /// Card background (`Card` variant "card", card blocks, accordions).
  final Color surface;

  /// Recessed background (`variant: "sunk"`, table headers).
  final Color surfaceSunk;

  /// Floating surfaces: tooltips, sheets, modals.
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;

  /// Headings and emphasised values.
  final Color textStrong;
  final Color text;

  /// Subtitles, hints, secondary lines.
  final Color textMuted;

  /// Axis labels and the faintest annotations.
  final Color textFaint;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color primaryBorder;
  final Color primaryText;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color chip;
  final Color chipBorder;

  /// Image placeholders.
  final Color skeleton;

  /// Categorical colours for chart series and slices, in assignment order.
  final List<Color> chartPalette;
  final String? fontFamily;

  /// Body text size; every other size is relative to it.
  final double baseFontSize;

  /// Corner radius of cards and other large surfaces.
  final double radius;
  final OpenUiMarkdownBuilder? markdownBuilder;
  final OpenUiImageBuilder? imageBuilder;

  static const defaultChartPalette = [
    Color(0xFF7C8CFF),
    Color(0xFF34D399),
    Color(0xFFF59E0B),
    Color(0xFFF472B6),
    Color(0xFF60A5FA),
    Color(0xFFA78BFA),
    Color(0xFFF87171),
    Color(0xFF22D3EE),
    Color(0xFFFB923C),
    Color(0xFFA3E635),
    Color(0xFFE879F9),
    Color(0xFF94A3B8),
  ];

  Color chartColor(int i) => chartPalette[i % chartPalette.length];

  /// The variant colours of Callout, Tag, IconText… (`info`, `success`,
  /// `warning`, `error`/`danger`); anything else is neutral.
  Color variant(String? name) => switch (name) {
    'info' => info,
    'success' => success,
    'warning' => warning,
    'error' || 'danger' => danger,
    _ => textMuted,
  };

  /// A text style [delta] points off the base size.
  TextStyle body({
    double delta = 0,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.45,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: baseFontSize + delta,
    fontWeight: weight,
    height: height,
    color: color ?? text,
  );

  OpenUiThemeData copyWith({
    Color? surface,
    Color? surfaceSunk,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? textStrong,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? primaryBorder,
    Color? primaryText,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? chip,
    Color? chipBorder,
    Color? skeleton,
    List<Color>? chartPalette,
    String? fontFamily,
    double? baseFontSize,
    double? radius,
    OpenUiMarkdownBuilder? markdownBuilder,
    OpenUiImageBuilder? imageBuilder,
  }) => OpenUiThemeData(
    surface: surface ?? this.surface,
    surfaceSunk: surfaceSunk ?? this.surfaceSunk,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    textStrong: textStrong ?? this.textStrong,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    textFaint: textFaint ?? this.textFaint,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primarySoft: primarySoft ?? this.primarySoft,
    primaryBorder: primaryBorder ?? this.primaryBorder,
    primaryText: primaryText ?? this.primaryText,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    chip: chip ?? this.chip,
    chipBorder: chipBorder ?? this.chipBorder,
    skeleton: skeleton ?? this.skeleton,
    chartPalette: chartPalette ?? this.chartPalette,
    fontFamily: fontFamily ?? this.fontFamily,
    baseFontSize: baseFontSize ?? this.baseFontSize,
    radius: radius ?? this.radius,
    markdownBuilder: markdownBuilder ?? this.markdownBuilder,
    imageBuilder: imageBuilder ?? this.imageBuilder,
  );
}

/// Provides [OpenUiThemeData] to the components below it.
class OpenUiTheme extends InheritedWidget {
  const OpenUiTheme({super.key, required this.data, required super.child});

  final OpenUiThemeData data;

  static OpenUiThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OpenUiTheme>()?.data ??
      OpenUiThemeData.fromTheme(Theme.of(context));

  @override
  bool updateShouldNotify(OpenUiTheme old) => data != old.data;
}
