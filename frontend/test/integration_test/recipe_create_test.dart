import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared_routines.dart';

Future<void> performLogin(tester) async {
  final usernameKey = const Key('username');
  final passwordKey = const Key('password');
  final loginKey = const Key('login');
  final loginButton = find.byKey(loginKey);

  await tester.enterText(find.byKey(passwordKey), 'admin'); // why the fuck
  await tester.enterText(find.byKey(usernameKey), 'admin');
  await tester.enterText(find.byKey(passwordKey), 'admin');
  await tester.tap(loginButton);
  await tester.pumpAndSettle();
}

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
      // Assume a reasonably large screen
      final dpi = tester.view.devicePixelRatio;
      tester.view.physicalSize = Size(904 * dpi, 1000 * dpi);

      await startAppDefault(tester,
          sharedPrefs: sharedPrefs, database: database);
      await performLogin(tester);
      final addRecipeButton = find.byKey(const Key('appbar_addrecipe_icon'));
      expect(addRecipeButton, findsOneWidget);

      // For now there should be no recipes
      final recipeListTiles = find.byKey(const Key('recipeListTile'));
      expect(recipeListTiles, findsNothing);

      // Open the recipe creator mode
      await tester.tap(addRecipeButton);
      await tester.pumpAndSettle();

      //////////////////////////////////////////////////////////////////////////
      /// Initial Condition Check
      //////////////////////////////////////////////////////////////////////////

      // fields
      final recipeVisibilityCheckboxKey = const Key("recipeVisibilityCheckbox");
      final recipeTitleFieldKey = const Key("recipeTitleField");
      final recipeLanguageDropdownKey = const Key("recipeLanguageDropdown");
      final recipeSubtitleFieldKey = const Key("recipeSubtitleField");
      final recipeCommentFieldKey = const Key("recipeCommentField");
      final recipeDifficultySelectorKey = const Key("recipeDifficultySelector");
      final recipeServingsFieldKey = const Key("recipeServingsField");
      final recipeCategoriesSelectorKey = const Key("recipeCategoriesSelector");
      final recipePrepTimeFieldKey = const Key("recipePrepTimeField");
      final recipeCookTimeFieldKey = const Key("recipeCookTimeField");
      final recipeSourceNameFieldKey = const Key("recipeSourceNameField");
      final recipeSourcePageFieldKey = const Key("recipeSourcePageField");
      final recipeSourceUrlFieldKey = const Key("recipeSourceUrlField");

      final fieldList = [
        recipeTitleFieldKey,
        recipeSubtitleFieldKey,
        recipeCommentFieldKey,
        recipeServingsFieldKey,
        recipePrepTimeFieldKey,
        recipeCookTimeFieldKey,
        recipeSourceNameFieldKey,
        recipeSourcePageFieldKey,
        recipeSourceUrlFieldKey,
      ];

      // check that all fields are empty after opening the recipe creator
      for (var field in fieldList) {
        expect(find.byKey(field), findsOneWidget);
        final TextFormField formfield =
            tester.widget<TextFormField>(find.byKey(field));
        if (field == recipeServingsFieldKey) {
          expect(formfield.controller!.text, "1");
        } else {
          expect(formfield.controller!.text, "");
        }
      }

      expect(find.byKey(recipeVisibilityCheckboxKey), findsOne);
      expect(find.byKey(recipeLanguageDropdownKey), findsOne);
      expect(find.byKey(recipeDifficultySelectorKey), findsOne);
      expect(find.byKey(recipeCategoriesSelectorKey), findsOne);

      // buttons
      final recipeBackButtonKey = const Key("recipeBackButton");
      final recipeRestoreButtonKey = const Key("recipeRestoreButton");
      final recipeSaveCloseButtonKey = const Key("recipeSaveCloseButton");
      final recipeSaveButtonKey = const Key("recipeSaveButton");
      final recipeSaveDraftButtonKey = const Key("recipeSaveDraftButton");
      expect(find.byKey(recipeBackButtonKey), findsOne);
      expect(find.byKey(recipeRestoreButtonKey), findsOne);
      expect(find.byKey(recipeSaveCloseButtonKey), findsOne);
      final saveButton = find.byKey(recipeSaveButtonKey);
      expect(saveButton, findsOne);
      expect(find.byKey(recipeSaveDraftButtonKey), findsOne);

      //////////////////////////////////////////////////////////////////////////
      /// Fill fields (partial - not complete for saving)
      //////////////////////////////////////////////////////////////////////////
      await attemptSave(tester, saveButton);
      final missingFields = find.text("Field must be filled",
          findRichText: true, skipOffstage: false);
      expect(missingFields, findsExactly(3));

      await tester.enterText(find.byKey(recipeTitleFieldKey), 'Test-Recipe');
      await tester.enterText(find.byKey(recipePrepTimeFieldKey), '43');
      await tester.enterText(find.byKey(recipeCookTimeFieldKey), '44');
      await attemptSave(tester, saveButton);
      final missingFields2 = find.text("Field must be filled",
          findRichText: true, skipOffstage: false);
      expect(missingFields2, findsNothing);

      await tester.enterText(find.byKey(recipeServingsFieldKey), '100');
      await attemptSave(tester, saveButton);
      final errMsg = find.text("Needs to be smaller than or equal to 99.",
          findRichText: true, skipOffstage: false);
      expect(errMsg, findsOneWidget);

      await tester.enterText(find.byKey(recipeServingsFieldKey), '42');
      await attemptSave(tester, saveButton);
      final errMsg3 = find.text("Needs to be smaller than or equal to 99.",
          findRichText: true, skipOffstage: false);
      expect(errMsg3, findsNothing);

      /// FIXME: The following test is failing
      // await tester.pumpAndSettle();
      // tester.ensureVisible(find.byKey(recipeServingsFieldKey));
      // await tester.enterText(find.byKey(recipeServingsFieldKey), '0');
      // await attemptSave(tester, saveButton);
      // final errMsg2 = find.text("Needs to be larger than or equal to 1.",
      //     findRichText: true, skipOffstage: false);
      // expect(errMsg2, findsOneWidget);

      await tester.enterText(find.byKey(recipeServingsFieldKey), '42');
      await attemptSave(tester, saveButton);
      final errMsg4 = find.text("Needs to be larger than or equal to 1.",
          findRichText: true, skipOffstage: false);
      expect(errMsg4, findsNothing);

      // Now we have all the necessary fields filled, but no categories selected
      final errMsgMissingCategory = find.text("Choose at least one!",
          findRichText: true, skipOffstage: false);
      expect(errMsgMissingCategory, findsOneWidget);

      final categoryOne = find.byKey(const Key("recipeCategoryChip_1"));
      expect(categoryOne, findsOneWidget);
      await tester.tap(categoryOne);
      await tester.pumpAndSettle();
      final errMsgMissingCategory2 = find.text("Choose at least one!",
          findRichText: true, skipOffstage: false);
      expect(errMsgMissingCategory2, findsNothing);

      // optional fields not necessary for saving
      await tester.enterText(
          find.byKey(recipeSubtitleFieldKey), 'Test-Subtitle');
      await tester.enterText(find.byKey(recipeCommentFieldKey), 'Test-Comment');
      await tester.enterText(
          find.byKey(recipeSourceNameFieldKey), 'Test-Source-Name');
      await tester.enterText(find.byKey(recipeSourcePageFieldKey), '45');
      await tester.enterText(
          find.byKey(recipeSourceUrlFieldKey), 'https://example.com');

      final saveAndCloseButton = find.byKey(recipeSaveCloseButtonKey);
      await tester.ensureVisible(saveAndCloseButton);
      await tester.tap(saveAndCloseButton);
      await tester.pumpAndSettle();

      final recipeTitleWidget = find.byKey(Key("RecipeTitleWidget"));
      expect(recipeTitleWidget, findsOne);
    });
  });
}
