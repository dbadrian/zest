import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zest/authentication/auth_service.dart';
import 'package:zest/ui/login_screen.dart';

import '../config/constants.dart';
import '../ui/widgets/divider_text.dart';
import '../ui/widgets/generics.dart';
import 'settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  static String get routeName => 'settings';
  static String get routeLocation => '/$routeName';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      appBar: null,
      resizeToAvoidBottomInset: true,
      body: SettingsForm(),
    );
  }
}

class SettingsForm extends ConsumerStatefulWidget {
  const SettingsForm({super.key});

  @override
  SettingsFormState createState() => SettingsFormState();
}

class SettingsFormState extends ConsumerState<SettingsForm> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildShowAdvancedSettingsCheckbox(ref),
            const DividerText(text: "Theme"),
            buildThemeOption(ref),
            buildThemeBaseColorOption(ref, context),
            const DividerText(text: "Language"),
            buildLanguageSelector(ref),
            buildSearchLanguageIndicator(ref),
            buildAdvancedSettings(ref),
            const SizedBox(height: 20),
            buildScreenButtons(context, ref),
          ],
        ),
      ),
    );
  }
}

Widget buildThemeBaseColorOption(ref, context) {
  final settings = ref.read(settingsProvider.notifier);
  return ListTile(
    leading: const Icon(Icons.colorize),
    title: Text("Color Scheme",
        style:
            TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
    trailing: ElevatedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Pick a color!'),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: ref.watch(settingsProvider
                      .select((settings) => settings.dirty.themeBaseColor)),
                  onColorChanged: (color) {
                    // pickerColor = color;
                    settings.setPickerColor(color);
                  },
                ),
              ),
              actions: <Widget>[
                ElevatedButton(
                  child: const Text('Got it'),
                  onPressed: () {
                    settings.setThemeColor(ref.watch(settingsProvider
                        .select((settings) => settings.dirty.pickerColor)));
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
      child: const Text("Pick Color"),
    ),
  );
}

Widget buildThemeOption(ref) {
  final settings = ref.read(settingsProvider.notifier);
  final useDarkTheme = ref.watch(
      settingsProvider.select((settings) => settings.dirty.useDarkTheme));
  return SwitchListTile(
      secondary: const Icon(Icons.palette),
      title: const Text("Use Dark Theme"),
      value: useDarkTheme,
      onChanged: (bool? newValue) {
        settings.setUseDarkTheme(newValue);
      });

  // return ListTile(
  //   leading: const Icon(Icons.palette),
  //   title: const Text("Theme"),
  //   trailing: DropdownButton<String>(
  //       value: useDarkTheme ? 'dark' : 'light',
  //       icon: const Icon(Icons.arrow_downward),
  //       iconSize: 24,
  //       elevation: 16,
  //       // style: const TextStyle(color: Colors.deepPurple),
  //       underline: Container(
  //         height: 2,
  //         color: Theme.of(ref).colorScheme.primary,
  //       ),
  //       onChanged: (String? newValue) {
  //         settings.setUseDarkTheme(newValue == 'dark');
  //       },
  //       items: const [
  //         DropdownMenuItem<String>(
  //           value: 'light',
  //           child: Text('Light'),
  //         ),
  //         DropdownMenuItem<String>(
  //           value: 'dark',
  //           child: Text('Dark'),
  //         ),
  //       ]),
  // );
}

Widget buildSearchLanguageIndicator(ref) {
  final settings = ref.read(settingsProvider.notifier);
  final bool searchAllLanguages = ref.watch(
      settingsProvider.select((settings) => settings.dirty.searchAllLanguages));
  return SwitchListTile(
    value: searchAllLanguages,
    onChanged: (bool value) {
      settings.setSearchAllLanguages(value);
    },
    title: const Text("Show recipes from all languages"),
    subtitle: const Text(
        "By default only recipes from the user language are shown..."),
    secondary: const Icon(Icons.language),
  );
}

Widget buildLanguageSelector(ref) {
  final settings = ref.read(settingsProvider.notifier);
  final String language =
      ref.watch(settingsProvider.select((settings) => settings.dirty.language));
  return ListTile(
    leading: const Icon(Icons.description_outlined),
    title: const Text("Display Language"),
    trailing: DropdownButton<String>(
        value: language,
        icon: const Icon(Icons.arrow_downward),
        iconSize: 24,
        elevation: 16,
        // style: const TextStyle(color: Colors.deepPurple),
        underline: Container(
          height: 2,
          color: Theme.of(ref).colorScheme.primary,
        ),
        onChanged: (String? newValue) {
          settings.setLanguage(newValue ?? language);
        },
        items: [
          for (final entry in AVAILABLE_LANGUAGES.entries)
            DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
        ]),
  );
}

Widget buildShowAdvancedSettingsCheckbox(ref) {
  final settings = ref.read(settingsProvider.notifier);
  final bool showAdvancedSettings = ref.watch(settingsProvider
      .select((settings) => settings.dirty.showAdvancedSettings));

  return LayoutBuilder(
    builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 360;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: const TextStyle(fontSize: 20)),
          CheckboxListTile(
            value: showAdvancedSettings,
            onChanged: (bool? value) {
              settings.setShowAdvancedSettings(value!);
            },
            title: const Text("Show Advanced"),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.trailing,
          ),
        ],
      );
    },
  );
}

class APIFieldWidget extends HookConsumerWidget {
  const APIFieldWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider.notifier);
    final apiUrl = ref.watch(settingsProvider.select((s) => s.dirty.apiUrl));
    final TextEditingController apiUrlCtrl = useTextEditingController();

    // The following updates the text-editing controller with the current value
    // but it will also reset the cursor position to the end of the text
    // hence we need to cache the position -> seleciton
    final cacheSelection = apiUrlCtrl.selection;
    apiUrlCtrl.text = apiUrl; // to refresh the text on changes
    apiUrlCtrl.selection = TextSelection.fromPosition(TextPosition(
        offset: min(apiUrlCtrl.text.length, cacheSelection.baseOffset)));

    final bool isValidURL = Uri.tryParse(apiUrl)?.hasAbsolutePath ?? false;
    var errorText = "";
    if (ref.watch(settingsProvider.select((s) => s.dirty.apiUrlDirty))) {
      errorText = "The API URL is changed, if saved you will be logged out.";
    }
    if (!isValidURL)
      errorText += errorText.isEmpty ? "Invalid URL!" : "\nInvalid URL!";

    return ListTile(
      leading: const Icon(Icons.connect_without_contact),
      title: const Text("API"),
      subtitle: TextFormField(
        controller: apiUrlCtrl,
        onChanged: settings.setApiUrl,
        decoration: InputDecoration(
          hintText: 'https://your-domain.com/api/v1',
          errorText: errorText.isEmpty ? null : errorText,
        ),
      ),
    );
  }
}

Widget _buildAdvancedSettingsImpl(ref) {
  return const Column(
    children: [
      APIFieldWidget(),
    ],
  );
}

Widget buildAdvancedSettings(ref) {
  final bool showAdvancedSettings = ref.watch(settingsProvider
      .select((settings) => settings.dirty.showAdvancedSettings));
  return Column(
    children: [
      if (showAdvancedSettings)
        const Column(children: [
          ElementsVerticalSpace(),
          DividerText(text: "Advanced Settings"),
        ]),
      if (showAdvancedSettings) _buildAdvancedSettingsImpl(ref),
    ],
  );
}

Widget buildScreenButtons(context, ref) {
  final settings = ref.read(settingsProvider.notifier);

  return Wrap(
    spacing: 12,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: [
      OutlinedButton(
        onPressed: () {
          settings.discardChanges();
          GoRouter.of(context).pop();
        },
        child: const Text("Back"),
      ),
      OutlinedButton(
        onPressed: settings.restoreDefaultSettings,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(ref).colorScheme.error),
          backgroundColor: Theme.of(ref).colorScheme.errorContainer,
        ),
        child: Text(
          "Restore Defaults",
          style:
              TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
        ),
      ),
      OutlinedButton(
        onPressed: settings.discardChanges,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(ref).colorScheme.error),
        ),
        child: Text(
          "Discard Changes",
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      ElevatedButton(
        onPressed: () async {
          await settings.persistSettings();
          if (ref.read(settingsProvider.select((s) => s.dirty.apiUrlDirty))) {
            await ref.read(authenticationServiceProvider.notifier).logout();
            GoRouter.of(context).go(LoginPage.routeLocation);
          } else {
            GoRouter.of(context).pop(); // go back to where we where
          }
        },
        child: const Text("Save"),
      ),
    ],
  );
}
