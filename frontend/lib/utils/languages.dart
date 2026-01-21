import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String getLanguageInfoPlusAssetPath(String languageCode) {
  return 'packages/language_info_plus/assets/localized_names/$languageCode.json';
}

/// Initialize localized names based on the device's language
Future<Map<String, String>> getLocalizedLanguages(String languageCode) async {
  try {
    final String assetPath = getLanguageInfoPlusAssetPath(languageCode);
    final String jsonString = await rootBundle.loadString(assetPath);

    return Map<String, String>.from(json.decode(jsonString));
  } catch (_) {
    return {};
  }
}
