import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zest/settings/settings_provider.dart';
import 'package:zest/utils/duration.dart';

class RecipeListTile extends ConsumerWidget {
  const RecipeListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.totalTime,
    this.cookTime,
    this.prepTime,
    this.difficulty,
    this.language,
    this.categories,
    this.isFavorite,
    this.onTap,
    required this.isAlt,
    required this.isHighlighted,
    this.onDelete,
  });

  final String title;
  final String? subtitle;
  final int? totalTime;
  final int? cookTime;
  final int? prepTime;
  final int? difficulty;
  final bool? isFavorite;
  final String? language;
  final List<String>? categories;

  final GestureTapCallback? onTap;
  final bool isAlt;
  final bool isHighlighted;

  final Function()? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: const Key("recipeListTile"),
      // trailing: ,

      trailing: SizedBox(
        width: 100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (language != null &&
                language!.isNotEmpty &&
                language != ref.watch(settingsProvider).current.language)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CountryFlag.fromLanguageCode(
                    language!,
                    height: 20,
                    width: 30,
                    shape: const RoundedRectangle(6),
                  )
                ],
              ),
            SizedBox(
              width: 10,
            ),
            if (onDelete != null)
              IconButton(
                key: const Key("deleteIcon"),
                icon: const Icon(Icons.delete),
                onPressed: onDelete,
                // make it lightlight shaded
              ),
          ],
        ),
      ),
      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
      title: Row(children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (isFavorite != null && isFavorite!)
          Icon(
            key: const Key("favoriteIcon"),
            Icons.favorite,
            color: Theme.of(context).colorScheme.primary,
          ),
      ]),
      subtitle: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: subtitle,
              style: TextStyle(
                  // fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
            TextSpan(
              text:
                  "${subtitle?.isNotEmpty ?? false ? "\n" : ""}${getMetaInformation()}",
              style: TextStyle(
                // fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      // Text(
      //   "${subtitle}\n${getMetaInformation()}",
      //   style: TextStyle(fontStyle: FontStyle.italic),
      // ),
      tileColor: isAlt
          ? Theme.of(context).colorScheme.surfaceDim
          : Theme.of(context).colorScheme.surfaceContainerHigh,
      hoverColor: Theme.of(context).colorScheme.onPrimary,
      // te : Theme.of(context).colorScheme.onPrimary,
      textColor: isAlt
          ? Theme.of(context).colorScheme.onSurface
          : Theme.of(context).colorScheme.onSurface,
      onTap: onTap,
      isThreeLine: subtitle?.isNotEmpty ?? false,
    );
  }

  String getMetaInformation() {
    List<String> meta = [];
    if (totalTime != null && totalTime! > 0) {
      meta.add("Total time: ${totalTime}min");
    }
    if (cookTime != null && cookTime! > 0) {
      meta.add(
          "Cook time: ${durationToHourMinuteString(Duration(minutes: cookTime ?? 0), verbose: true)}");
    }
    if (prepTime != null && prepTime! > 0) {
      meta.add(
          "Prep time: ${durationToHourMinuteString(Duration(minutes: prepTime ?? 0), verbose: true)}");
    }
    if (difficulty != null && difficulty! > 0) {
      meta.add("Difficulty: $difficulty / 3");
    }
    if (categories != null && categories!.isNotEmpty) {
      meta.add(categories!.join(", "));
    }

    return meta.join(" | ");
  }
}
