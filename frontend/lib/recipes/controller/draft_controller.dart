import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/config/constants.dart';
import 'package:zest/main.dart';
import 'package:zest/recipes/controller/edit_controller.dart';

part 'draft_controller.freezed.dart';
part 'draft_controller.g.dart';

@freezed
class RecipeDraftSearchState with _$RecipeDraftSearchState {
  const factory RecipeDraftSearchState({
    @Default({}) Map<int, RecipeEditState> recipeDraftList,
  }) = _RecipeDraftSearchState;
}

@Riverpod()
class RecipeDraftSearchController extends _$RecipeDraftSearchController {
  @override
  Future<RecipeDraftSearchState> build() async {
    return await _loadFromDB();
  }

  Future<RecipeDraftSearchState> _loadFromDB() async {
    debugPrint("Loading Recipe-Drafts from DB...");
    final db = ref.read(sqliteDbProvider);
    var query = List.of(
        await db.query(RECIPE_DRAFT_DB_KEY)); // clone to be able to sort it...
    query.sort((a, b) {
      return (b["updatedLast"] as int? ?? 0)
          .compareTo((a["updatedLast"] as int? ?? 0));
    });
    final drafts = {
      for (var item in query)
        item["id"] as int:
            RecipeEditState.fromDBMap(item as Map<String, dynamic>)
    };

    return RecipeDraftSearchState(recipeDraftList: drafts);
  }

  void reload() async {
    state = const AsyncLoading();
    state = AsyncData(await _loadFromDB());
  }

  RecipeEditState? getById(int id) {
    if (state.hasValue) {
      return state.value!.recipeDraftList[id];
    }

    return null;
  }

  void deleteAllDrafts() async {
    final db = ref.read(sqliteDbProvider);
    final numDeleted = await db.delete(
      RECIPE_DRAFT_DB_KEY,
    );
    debugPrint("Deleted $numDeleted drafts from local db!");
    state = AsyncData(state.value!.copyWith(recipeDraftList: {}));
  }

  void deleteDraft(int id) async {
    final db = ref.read(sqliteDbProvider);
    final numDeleted = await db.delete(
      RECIPE_DRAFT_DB_KEY,
      where: "id = ?",
      whereArgs: [id],
    );
    debugPrint("Deleted $numDeleted drafts from local db!");
    final draftCopy = {...state.value!.recipeDraftList};
    draftCopy.remove(id);
    state = AsyncData(state.value!.copyWith(recipeDraftList: draftCopy));
  }
}
