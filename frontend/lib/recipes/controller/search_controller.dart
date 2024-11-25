import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/config/constants.dart';
import 'package:zest/config/zest_api.dart';
import 'package:zest/settings/knowledge_provider.dart';
import 'package:zest/settings/settings_provider.dart';

import '../../api/api_service.dart';
import '../../api/responses/recipe_list_response.dart';
import '../models/recipe_category.dart';

// class RecipeSearchController
//     extends StateNotifier<AsyncValue<RecipeListResponse>> {
//   RecipeSearchController(this.apiService) : super(const AsyncValue.loading());

part 'search_controller.freezed.dart';
part 'search_controller.g.dart';

@freezed
class FilterSettingsState with _$FilterSettingsState {
  const factory FilterSettingsState({
    @Default(RECIPE_SEARCH_DEFAULT_PAGE_SIZE) int pageSize,
    @Default({}) Set<String> lcFilter,
    // TODO: Long-term we might nt want to duplicate this setting here and in settings tab
    @Default(false) bool showAllLanguages,
    RecipeListResponse? recipeList,
    @Default(false) bool filterOwner,
    @Default(false) bool favoritesOnly,
    @Default([]) List<String> searchFields,
    @Default([]) List<RecipeCategory> categories,
  }) = _FilterSettingsState;
}

@riverpod
class RecipeSearchFilterSettings extends _$RecipeSearchFilterSettings {
  @override
  FilterSettingsState build() {
    return reset_();
  }

  FilterSettingsState reset_() {
    // Filter by language
    // Default: we only show the current user language, unless user
    // specified to always show all languages
    final showAllLanguages =
        ref.watch(settingsProvider.select((s) => s.searchAllLanguages));
    Set<String> lcFilter = {};
    if (showAllLanguages) {
      lcFilter.addAll(AVAILABLE_LANGUAGES.keys);
    } else {
      lcFilter.add(ref.watch(settingsProvider.select((s) => s.language)));
    }
    return FilterSettingsState(
      lcFilter: lcFilter,
      showAllLanguages: showAllLanguages,
      searchFields: API_RECIPE_SEARCH_FIELDS.entries
          .where((element) => element.value.right)
          .map((e) => e.key)
          .toList(),
    );
  }

  void reset() {
    state = reset_();
  }

  void updateFilterOwner(bool update) {
    state = state.copyWith(filterOwner: update);
  }

  void updateSearchFields(List<String> update) {
    state = state.copyWith(searchFields: update);
  }

  void updateShowAllLanguages(bool showAll) {
    if (showAll) {
      state = state.copyWith(
        showAllLanguages: true,
        lcFilter: AVAILABLE_LANGUAGES.keys.toSet(),
      );
    } else {
      state = state.copyWith(
        showAllLanguages: false,
        lcFilter: {ref.watch(settingsProvider.select((s) => s.language))},
      );
    }
  }

  void updateFavoritesOnly(bool favoritesOnly) {
    state = state.copyWith(favoritesOnly: favoritesOnly);
  }

  void updateCategories(List<int>? categories) {
    final newCategories = categories!
        .map((e) =>
            ref.watch(knowledgeProvider).value?.validRecipeCategoryChoices[e])
        .where((element) => element != null)
        .cast<RecipeCategory>()
        .toList();
    state = state.copyWith(categories: newCategories);
  }
}

@freezed
class RecipeSearchState with _$RecipeSearchState {
  const factory RecipeSearchState({
    @Default("") String currentQuery,
    RecipeListResponse? recipeList,
  }) = _RecipeSearchState;
}

bool nextPageAvailable(RecipeListResponse? recipeList) {
  if (recipeList != null) {
    final pagination = recipeList.pagination;
    return pagination.currentPage < pagination.totalPages;
  }
  return false;
}

@riverpod
class RecipeSearchController extends _$RecipeSearchController {
  @override
  FutureOr<RecipeSearchState> build() async {
    searchRecipes(state.value?.currentQuery ?? ""); // trigger initial build...
    return const RecipeSearchState();
  }

  Future<AsyncValue<RecipeListResponse>> _loadRecipes(
      {required String query,
      required int page,
      required FilterSettingsState filterSettings}) {
    return AsyncValue.guard(() => ref.read(apiServiceProvider).getRecipes(
        // pagination related
        page: page,
        pageSize: filterSettings.pageSize,
        // query related
        search: query,
        favoritesOnly: filterSettings.favoritesOnly,
        lcFilter: filterSettings.lcFilter.toList(),
        categories: filterSettings.categories.map((e) => e.id).toList(),
        searchFields: filterSettings.searchFields
            .map<String>((e) => API_RECIPE_SEARCH_FIELDS[e]!.left)
            .toList(),
        user: filterSettings.filterOwner ? "owner" : null));
  }

  void searchRecipes(String query) async {
    // get and watch current recipeFilterSettings
    final filterSettings = ref.watch(recipeSearchFilterSettingsProvider);

    final ret = await _loadRecipes(
        query: query, page: 1, filterSettings: filterSettings);
    ret.when(
      data: (data) {
        state =
            AsyncData(RecipeSearchState(currentQuery: query, recipeList: data));
      },
      error: ((error, stackTrace) {
        state = AsyncError(error, stackTrace);
      }),
      loading: (() {
        state = const AsyncValue.loading();
      }),
    );
  }

  void loadNextRecipePage() async {
    final filterSettings = ref.watch(recipeSearchFilterSettingsProvider);

    if (nextPageAvailable(state.value!.recipeList)) {
      final ret = await _loadRecipes(
        query: state.value!.currentQuery,
        page: state.value!.recipeList!.pagination.currentPage + 1,
        filterSettings: filterSettings,
      );
      ret.when(
        data: (data) {
          // We create a new state from the latest response as to have the updated pagination
          // but we genearte the complete list of results
          final newRecipeList = ret.value!.copyWith(recipes: [
            ...state.value!.recipeList!.recipes,
            ...ret.value!.recipes
          ]);
          state = AsyncData(state.value!.copyWith(recipeList: newRecipeList));
        },
        error: ((error, stackTrace) {
          state = AsyncError(error, stackTrace);
        }),
        loading: (() {
          state = const AsyncValue.loading();
        }),
      );
    }
  }
}
