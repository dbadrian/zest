// https://github.com/retroportalstudio/flutter_theming
import 'package:flutter/material.dart';

final baseInputDecoration = InputDecorationTheme(
  isDense: true,
  contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
  ),
  filled: true,
  fillColor: Colors.grey.withOpacity(0.005),
  floatingLabelStyle: const TextStyle(
    // fontSize: 10,
    // fontFamily: "Montserrat",
    fontWeight: FontWeight.w100,
  ),
  hintStyle: const TextStyle(
    // fontFamily: "Montserrat",
    fontWeight: FontWeight.w100,
  ),
  labelStyle: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w100,
  ),
);

ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Monserrat',

  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.teal,
    // ···
    brightness: Brightness.light,
  ),

  // brightness: Brightness.light,
  // primaryColor: colorPrimary,
  // floatingActionButtonTheme:
  //     const FloatingActionButtonThemeData(backgroundColor: colorAccent),
  // elevatedButtonTheme: ElevatedButtonThemeData(
  //     style: ButtonStyle(
  //         padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
  //             const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0)),
  //         shape: WidgetStateProperty.all<OutlinedBorder>(RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(20.0))),
  //         backgroundColor: WidgetStateProperty.all<Color>(colorAccent))),
  // inputDecorationTheme: baseInputDecoration.copyWith(filled: true),
);

ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Monserrat',
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.teal,
    // ···
    brightness: Brightness.dark,
  ),
);

// ThemeData darkTheme = ThemeData(
//   useMaterial3: true,
//   fontFamily: 'Monserrat',
//   brightness: Brightness.dark,
//   switchTheme: SwitchThemeData(
//     trackColor: WidgetStateProperty.all<Color>(Colors.grey),
//     thumbColor: WidgetStateProperty.all<Color>(Colors.white),
//   ),
//   inputDecorationTheme: baseInputDecoration,
//   elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ButtonStyle(
//           padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
//               const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0)),
//           shape: WidgetStateProperty.all<OutlinedBorder>(RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20.0))),
//           backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
//           foregroundColor: WidgetStateProperty.all<Color>(Colors.black),
//           overlayColor: WidgetStateProperty.all<Color>(Colors.black26))),
// );
