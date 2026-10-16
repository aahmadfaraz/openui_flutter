import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import 'lucide_names.dart';

/// A topical icon for `Icon(name, category)` when the name doesn't resolve —
/// upstream's `categoryFallbacks` (the lucide categories the prompt names),
/// plus a few loose aliases models also use.
const _categoryFallbacks = <String, String>{
  'accessibility': 'accessibility',
  'account': 'user',
  'animals': 'cat',
  'arrows': 'arrow-right',
  'brands': 'box',
  'buildings': 'building',
  'charts': 'chart-line',
  'communication': 'message-square',
  'connectivity': 'wifi',
  'cursors': 'mouse-pointer',
  'design': 'palette',
  'development': 'code',
  'devices': 'smartphone',
  'emoji': 'face-slightly-smiling',
  'files': 'file',
  'finance': 'dollar-sign',
  'food-beverage': 'cooking-pot',
  'gaming': 'gamepad',
  'home': 'house',
  'layout': 'layout-dashboard',
  'mail': 'mail',
  'math': 'calculator',
  'medical': 'heart-pulse',
  'multimedia': 'music',
  'nature': 'tree-pine',
  'navigation': 'map-pin',
  'notifications': 'bell',
  'people': 'users',
  'photography': 'camera',
  'science': 'microscope',
  'seasons': 'sun',
  'security': 'shield',
  'shapes': 'circle',
  'shopping': 'shopping-cart',
  'social': 'share-2',
  'sports': 'trophy',
  'sustainability': 'leaf',
  'text': 'type',
  'time': 'clock',
  'tools': 'wrench',
  'transportation': 'car',
  'travel': 'plane',
  'weather': 'cloud',
  // Aliases.
  'fitness': 'dumbbell',
  'health': 'heart-pulse',
  'food': 'utensils',
  'transport': 'car',
  'money': 'wallet',
  'tech': 'cpu',
  'technology': 'cpu',
  'education': 'graduation-cap',
  'work': 'briefcase',
  'business': 'briefcase',
  'location': 'map-pin',
  'date': 'calendar',
  'media': 'play',
  'music': 'music',
  'analytics': 'chart-column',
  'data': 'database',
  'status': 'circle-check',
  'entertainment': 'clapperboard',
};

/// Resolves a Lucide icon by its kebab-case [name] (`"circle-check"`),
/// tolerating old Lucide names (`"check-circle"`) and casing, then falling
/// back to a [category] icon and finally a neutral dot.
IconData openUiIcon(String? name, {String? category}) {
  final key = (name ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_]+'), '-')
      .replaceAll(RegExp(r'^lucide-'), '');
  final hit =
      lucideIconsByName[key] ??
      // Lucide renamed `<thing>-circle` → `circle-<thing>` (and square).
      _swapShape(key) ??
      lucideIconsByName[_renamed[key]] ??
      // `building-2` → `building`.
      lucideIconsByName[key.replaceFirst(RegExp(r'-\d+$'), '')];
  if (hit != null) return hit;
  final fallback = _categoryFallbacks[(category ?? '').trim().toLowerCase()];
  return (fallback == null ? null : lucideIconsByName[fallback]) ??
      LucideIcons.circle_dot;
}

/// Names the web's lucide still has but this icon set spells differently.
const _renamed = {
  'smile': 'face-slightly-smiling',
  'smile-plus': 'face-slightly-smiling-plus',
  'layout': 'layout-dashboard',
};

IconData? _swapShape(String key) {
  final m = RegExp(r'^(.+)-(circle|square)$').firstMatch(key);
  if (m == null) return null;
  return lucideIconsByName['${m[2]}-${m[1]}'];
}
