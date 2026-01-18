import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/constants.dart';
import '../config/zest_api.dart';
import '../main.dart';

part 'settings_provider.freezed.dart';
part 'settings_provider.g.dart';

// Keys for basic settings
const _languageKey = 'settings_language';
const _searchAllLanguagesKey = 'settings_search_all_languages_key';
const apiUrlKey = 'settings_api_url';

const _themeUseDarkThemeKey = 'settings_useDarkTheme';
const _themeBaseColorKey = 'settings_themeBaseColor';
const _themeColorPickerKey = 'settings_pickerColor';

// Keys for advanced settings
const _showAdvancedSettingsKey = 'settings_show_advanced_settings';

const _baseColor = Color.fromARGB(255, 7, 228, 255);

@freezed
class SettingsStateData with _$SettingsStateData {
  const factory SettingsStateData({
    // Language: UI and Content
    // TODO: LOW: Default language should be infered based on system language
    @Default(DEFAULT_LANGUAGE) String language,
    @Default(false) bool searchAllLanguages,

    // Themeing
    @Default(false) bool useDarkTheme,
    @Default(_baseColor) Color themeBaseColor,
    @Default(_baseColor) Color pickerColor, // used for state of widget

    // API Related
    @Default(DEFAULT_API_URL) apiUrl,
    @Default(false) bool apiUrlDirty,

    // Advanced Settings
    @Default(false) bool showAdvancedSettings,
  }) = _SettingsStateData;
}

@freezed
class SettingsState with _$SettingsState {
  factory SettingsState({
    @Default(SettingsStateData()) SettingsStateData current,
    @Default(SettingsStateData()) SettingsStateData dirty,
  }) = _SettingsState;
}

@riverpod
class Settings extends _$Settings {
  @override
  SettingsState build() {
    return loadSettings();
  }

  void setUseDarkTheme(bool useDarkTheme) {
    state = state.copyWith.dirty(useDarkTheme: useDarkTheme);
  }

  void setPickerColor(Color pickerColor) {
    state = state.copyWith.dirty(pickerColor: pickerColor);
  }

  void setThemeColor(Color themeBaseColor) {
    state = state.copyWith.dirty(themeBaseColor: themeBaseColor);
  }

  void setLanguage(String language) {
    state = state.copyWith.dirty(language: language);
  }

  void setSearchAllLanguages(bool searchAllLanguages) {
    state = state.copyWith.dirty(searchAllLanguages: searchAllLanguages);
  }

  void setApiUrl(String apiUrl) {
    state = state.copyWith.dirty(apiUrl: apiUrl, apiUrlDirty: true);
  }

  void setShowAdvancedSettings(bool showAdvancedSettings) {
    state = state.copyWith.dirty(showAdvancedSettings: showAdvancedSettings);
  }

  SettingsState loadSettings() {
    final prefs = ref.read(sharedPreferencesProvider);
    // Theme
    final useDarkTheme = prefs.getBool(_themeUseDarkThemeKey) ?? false;
    final pickerColor =
        prefs.getInt(_themeColorPickerKey) ?? _baseColor.toARGB32();
    final themeBaseColor =
        prefs.getInt(_themeBaseColorKey) ?? _baseColor.toARGB32();
    // Language
    final language = prefs.getString(_languageKey) ?? DEFAULT_LANGUAGE;
    final searchAllLanguages = prefs.getBool(_searchAllLanguagesKey) ?? false;
    // Advanced
    final showAdvancedSettings =
        prefs.getBool(_showAdvancedSettingsKey) ?? false;
    final apiUrl = prefs.getString(apiUrlKey) ?? DEFAULT_API_URL;
    final apiUrlDirty = false;

    final gt = SettingsStateData(
        useDarkTheme: useDarkTheme,
        pickerColor: Color(pickerColor),
        themeBaseColor: Color(themeBaseColor),
        language: language,
        searchAllLanguages: searchAllLanguages,
        showAdvancedSettings: showAdvancedSettings,
        apiUrl: apiUrl,
        apiUrlDirty: apiUrlDirty);

    return SettingsState(current: gt, dirty: gt);
  }

  // Load settings from the sharedPrefs
  void discardChanges() {
    state = loadSettings();
  }

  // Load settings from the sharedPrefs
  void restoreDefaultSettings() {
    final gt = SettingsStateData(
        showAdvancedSettings: state.dirty.showAdvancedSettings);
    state = SettingsState(current: gt, dirty: gt);
  }

  // Write them to the sharedPrefs
  void persistSettings() async {
    // saveSettings(ref, state);
    final prefs = ref.read(sharedPreferencesProvider);
    // Theme
    prefs.setBool(_themeUseDarkThemeKey, state.dirty.useDarkTheme);
    prefs.setInt(_themeColorPickerKey, state.dirty.pickerColor.toARGB32());
    prefs.setInt(_themeBaseColorKey, state.dirty.themeBaseColor.toARGB32());
    // Language
    prefs.setString(_languageKey, state.dirty.language);
    prefs.setBool(_searchAllLanguagesKey, state.dirty.searchAllLanguages);
    // Advanced
    prefs.setBool(_showAdvancedSettingsKey, state.dirty.showAdvancedSettings);
    prefs.setString(apiUrlKey, state.dirty.apiUrl);

    state = state.copyWith(current: state.dirty.copyWith(apiUrlDirty: false));
  }
}
