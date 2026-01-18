import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared_routines.dart';

// Future<void> expectEmptyRecipe(tester) async {}

Future<void> attemptSave(WidgetTester tester, Finder saveButton) async {
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

void main() async {
  var (sharedPrefs, database) = await prepareAppForIntegrationTest();

  group('end-to-end test', () {
    testWidgets('Create Recipe Integration Test', (tester) async {
      await tester.runAsync(() async {
        await startAppDefault(
          tester,
          sharedPrefs: sharedPrefs,
          // database: database
        );
        // advance time and pretend animation is done
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        await performLogin(tester);

        final addRecipeButton = find.byKey(const Key('appbar_addrecipe_icon'));
        expect(addRecipeButton, findsOneWidget);

        // For now there should be no recipes
        final recipeListTiles = find.byKey(const Key('recipeListTile'));
        expect(recipeListTiles, findsNothing);

        // Open the recipe creator mode
        await tester.tap(addRecipeButton);
        await tester.pumpAndSettle();

        // //////////////////////////////////////////////////////////////////////////
        // /// Initial Condition Check
        // //////////////////////////////////////////////////////////////////////////

        // // fields
        final recipeVisibilityCheckboxKey =
            const Key("recipeIsPrivateCheckbox");
        final recipeDraftCheckbox = const Key("recipeDraftCheckbox");
        final recipeLanguageDropdownKey = const Key("recipeLanguageDropdown");
        final recipeDifficultySelectorKey =
            const Key("recipeDifficultySelector");
        final recipeServingsFieldKey = const Key("recipeServingsField");
        final recipeCategoriesSelectorKey =
            const Key("recipeCategoriesSelector");

        expect(find.byKey(recipeVisibilityCheckboxKey), findsOne);
        expect(find.byKey(recipeLanguageDropdownKey), findsOne);
        expect(find.byKey(recipeDraftCheckbox), findsOne);
        expect(find.byKey(recipeDifficultySelectorKey), findsOne);
        expect(find.byKey(recipeCategoriesSelectorKey), findsOne);

        final recipeTitleFieldKey = const Key("recipeTitleField");
        final recipeSubtitleFieldKey = const Key("recipeSubtitleField");
        final recipeCommentFieldKey = const Key("recipeCommentField");
        final recipePrepTimeHourFieldKey = const Key("recipePrep Time-hour");
        final recipePrepTimeMinuteFieldKey =
            const Key("recipePrep Time-minutes");
        final recipeCookTimeHourFieldKey = const Key("recipeCook Time-hour");
        final recipeCookTimeMinuteFieldKey =
            const Key("recipeCook Time-minutes");
        final recipeSourceNameFieldKey = const Key("recipeSourceNameField");
        final recipeSourcePageFieldKey = const Key("recipeSourcePageField");
        final recipeSourceUrlFieldKey = const Key("recipeSourceUrlField");

        final fieldList = [
          recipeTitleFieldKey,
          recipeSubtitleFieldKey,
          recipeCommentFieldKey,
          recipeServingsFieldKey,
          recipeSourceNameFieldKey,
          recipeSourcePageFieldKey,
          recipeSourceUrlFieldKey,
          recipePrepTimeHourFieldKey,
          recipePrepTimeMinuteFieldKey,
          recipeCookTimeHourFieldKey,
          recipeCookTimeMinuteFieldKey,
        ];

        // check that all fields are empty after opening the recipe creator
        try {
          for (var field in fieldList) {
            final _field = find.byKey(field);
            expect(_field, findsOneWidget);
            final TextFormField formfield =
                tester.widget<TextFormField>(_field);
            if (field == recipePrepTimeHourFieldKey ||
                field == recipePrepTimeMinuteFieldKey ||
                field == recipeCookTimeHourFieldKey ||
                field == recipeCookTimeMinuteFieldKey) {
              // expect(formfield.controller!.text, "0");
              // currently do nothing as there is no controller
            } else {
              expect(formfield.controller!.text, "");
            }
          }
        } catch (e, stack) {
          print('❌ Exception caught: $e');
          print(stack);
          rethrow; // important so the test still fails
        }

        // // buttons
        // final recipeBackButtonKey = const Key("recipeBackButton");
        // final recipeRestoreButtonKey = const Key("recipeRestoreButton");
        // final recipeSaveCloseButtonKey = const Key("recipeSaveCloseButton");
        // final recipeSaveButtonKey = const Key("recipeSaveButton");
        // final recipeSaveDraftButtonKey = const Key("recipeSaveDraftButton");
        // expect(find.byKey(recipeBackButtonKey), findsOne);
        // expect(find.byKey(recipeRestoreButtonKey), findsOne);
        // expect(find.byKey(recipeSaveCloseButtonKey), findsOne);
        // final saveButton = find.byKey(recipeSaveButtonKey);
        // expect(saveButton, findsOne);
        // expect(find.byKey(recipeSaveDraftButtonKey), findsOne);

        // //////////////////////////////////////////////////////////////////////////
        // /// Fill fields (partial - not complete for saving)
        // //////////////////////////////////////////////////////////////////////////
        // await attemptSave(tester, saveButton);
        // final missingFields = find.text("Field must be filled",
        //     findRichText: true, skipOffstage: false);
        // expect(missingFields, findsExactly(3));

        // await tester.enterText(find.byKey(recipeTitleFieldKey), 'Test-Recipe');
        // await tester.enterText(find.byKey(recipePrepTimeFieldKey), '43');
        // await tester.enterText(find.byKey(recipeCookTimeFieldKey), '44');
        // await attemptSave(tester, saveButton);
        // final missingFields2 = find.text("Field must be filled",
        //     findRichText: true, skipOffstage: false);
        // expect(missingFields2, findsNothing);

        // await tester.enterText(find.byKey(recipeServingsFieldKey), '100');
        // await attemptSave(tester, saveButton);
        // await tester.pumpAndSettle();
        // final errMsg = find.text("Needs to be smaller than or equal to 99.",
        //     findRichText: true, skipOffstage: false);
        // expect(errMsg, findsOneWidget);

        // await tester.enterText(find.byKey(recipeServingsFieldKey), '42');
        // await attemptSave(tester, saveButton);
        // final errMsg3 = find.text("Needs to be smaller than or equal to 99.",
        //     findRichText: true, skipOffstage: false);
        // expect(errMsg3, findsNothing);

        // /// FIXME: The following test is failing
        // // await tester.pumpAndSettle();
        // // tester.ensureVisible(find.byKey(recipeServingsFieldKey));
        // // await tester.enterText(find.byKey(recipeServingsFieldKey), '0');
        // // await attemptSave(tester, saveButton);
        // // final errMsg2 = find.text("Needs to be larger than or equal to 1.",
        // //     findRichText: true, skipOffstage: false);
        // // expect(errMsg2, findsOneWidget);

        // await tester.enterText(find.byKey(recipeServingsFieldKey), '42');
        // await attemptSave(tester, saveButton);
        // final errMsg4 = find.text("Needs to be larger than or equal to 1.",
        //     findRichText: true, skipOffstage: false);
        // expect(errMsg4, findsNothing);

        // // Now we have all the necessary fields filled, but no categories selected
        // final errMsgMissingCategory = find.text("Choose at least one!",
        //     findRichText: true, skipOffstage: false);
        // expect(errMsgMissingCategory, findsOneWidget);

        // final categoryOne = find.byKey(const Key("recipeCategoryChip_1"));
        // expect(categoryOne, findsOneWidget);
        // await tester.tap(categoryOne);
        // await tester.pumpAndSettle();
        // final errMsgMissingCategory2 = find.text("Choose at least one!",
        //     findRichText: true, skipOffstage: false);
        // expect(errMsgMissingCategory2, findsNothing);

        // // optional fields not necessary for saving
        // await tester.enterText(
        //     find.byKey(recipeSubtitleFieldKey), 'Test-Subtitle');
        // await tester.enterText(
        //     find.byKey(recipeCommentFieldKey), 'Test-Comment');
        // // TODO: since recipe source is now collapsed by default and optional
        // // we do not test for it fo the time being
        // // await tester.enterText(
        // //     find.byKey(recipeSourceNameFieldKey), 'Test-Source-Name');
        // // await tester.enterText(find.byKey(recipeSourcePageFieldKey), '45');
        // // await tester.enterText(
        // //     find.byKey(recipeSourceUrlFieldKey), 'https://example.com');

        // final saveAndCloseButton = find.byKey(recipeSaveCloseButtonKey);
        // await tester.ensureVisible(saveAndCloseButton);
        // await tester.tap(saveAndCloseButton);
        // await tester.pumpAndSettle();

        // // TODO: fix this
        // // final recipeTitleWidget = find.byKey(Key("RecipeTitleWidget"));
        // // // TODO: This should be one...recipe
        // // expect(recipeTitleWidget, findsOne);
      });
    });
  });
}
