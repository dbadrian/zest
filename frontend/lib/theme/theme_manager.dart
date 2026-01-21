// import 'package:flutter/material.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';

// import '../settings/settings_provider.dart';

// class ThemeManager extends StateNotifier<ThemeMode> {
//   ThemeManager() : super(ThemeMode.light);
//   get themeMode => state;
//   void toggleTheme() {
//     state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
//   }
// }

// final themeProvider = StateNotifierProvider<ThemeManager, ThemeMode>((ref) {
//   final useDark =
//       ref.watch(settingsProvider.select((settings) => settings.useDarkTheme));
//   // ? ref.read(themeProvider.notifier).state = ThemeMode.dark
//   // : ref.read(themeProvider.notifier).state = ThemeMode.light;
//   return ThemeManager();
// });
