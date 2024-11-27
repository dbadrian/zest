import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SettingsForm(),
          ],
        ),
      ),
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
    return Center(
      child: Column(
        children: [
          buildShowAdvancedSettingsCheckbox(ref),
          const DividerText(text: "Theme"),
          buildThemeOption(ref),
          buildThemeBaseColorOption(ref, context),
          const DividerText(text: "Language"),
          buildLanguageSelector(ref),
          buildSearchLanguageIndicator(ref),
          buildAdvancedSettings(ref),
          const ElementsVerticalSpace(),
          const ElementsVerticalSpace(),
          buildScreenButtons(context, ref)
        ],
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
                      .select((settings) => settings.themeBaseColor)),
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
                        .select((settings) => settings.pickerColor)));
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
  final useDarkTheme =
      ref.watch(settingsProvider.select((settings) => settings.useDarkTheme));
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
      settingsProvider.select((settings) => settings.searchAllLanguages));
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
      ref.watch(settingsProvider.select((settings) => settings.language));
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
  final bool showAdvancedSettings = ref.watch(
      settingsProvider.select((settings) => settings.showAdvancedSettings));
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 10, right: 10),
        child: Text(
          'Settings',
          style: TextStyle(fontSize: 20),
        ),
      ),
      SizedBox(
        width: 205,
        child: CheckboxListTile(
          value: showAdvancedSettings,
          onChanged: (bool? value) {
            settings.setShowAdvancedSettings(value!);
          },
          title: const Text("Show Advanced"),
        ),
      ),
    ],
  );
}

class APIFieldWidget extends HookConsumerWidget {
  const APIFieldWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider.notifier);
    final apiUrl = ref.watch(settingsProvider.select((s) => s.apiUrl));
    final TextEditingController apiUrlCtrl = useTextEditingController();

    // The following updates the text-editing controller with the current value
    // but it will also reset the cursor position to the end of the text
    // hence we need to cache the position -> seleciton
    final cachePosition = apiUrlCtrl.selection;
    apiUrlCtrl.text = apiUrl; // to refresh the text on changes
    apiUrlCtrl.selection = cachePosition;
    return ListTile(
      leading: const Icon(Icons.connect_without_contact),
      title: const Text("API"),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 40, maxWidth: 250),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: apiUrlCtrl,
                onChanged: ((value) => settings.setApiUrl(value)),
                // controller: ref.apiAddressCtrl,
                decoration: const InputDecoration(
                  // border: OutlineInputBorder(),
                  hintText: 'http://your-domain.com/api/v1',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
  final bool showAdvancedSettings = ref.watch(
      settingsProvider.select((settings) => settings.showAdvancedSettings));
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

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      OutlinedButton(
        onPressed: () async {
          settings.discardSettings();
          GoRouter.of(context).pop();
        },
        child: const Text("Back"),
      ),
      const SizedBox(
        width: 25,
      ),
      OutlinedButton(
        onPressed: settings.restoreDefaultSettings,
        style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(ref).colorScheme.error),
            backgroundColor: Theme.of(ref).colorScheme.errorContainer),
        child: Text(
          "Restore Defaults",
          style:
              TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
        ),
      ),
      const SizedBox(
        width: 25,
      ),
      ElevatedButton(
        onPressed: () {
          settings.persistSettings();
          // TODO: In the future, we would like to just pop the settings route,
          // however, this will require more logic to force a reload of data,
          // such as recipes which might require a refresh due to language changes.
          // GoRouter.of(context).goNamed(HomePage.routeName);
          GoRouter.of(context).pop();
        },
        child: const Text("Save"),
      ),
    ],
  );
}
