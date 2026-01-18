import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/config/constants.dart';
import 'package:zest/config/zest_api.dart';
import 'package:zest/recipes/recipe_repository.dart';
import 'package:zest/recipes/static_data_repository.dart';
import 'package:zest/settings/settings_provider.dart';

import '../../api/responses/recipe_list_response.dart';

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
    @Default([]) List<int> categories,
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
        ref.watch(settingsProvider.select((s) => s.current.searchAllLanguages));
    Set<String> lcFilter = {};
    if (showAllLanguages) {
      lcFilter.addAll(AVAILABLE_LANGUAGES.keys);
    } else {
      lcFilter
          .add(ref.watch(settingsProvider.select((s) => s.current.language)));
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
        lcFilter: {
          ref.watch(settingsProvider.select((s) => s.current.language))
        },
      );
    }
  }

  void updateFavoritesOnly(bool favoritesOnly) {
    state = state.copyWith(favoritesOnly: favoritesOnly);
  }

  void updateCategories(List<int> categories) async {
    state = state.copyWith(categories: categories);
  }
}

@freezed
class RecipeSearchState with _$RecipeSearchState {
  const factory RecipeSearchState({
    @Default("") String currentQuery,
    RecipeSearchListResponse? recipeList,
  }) = _RecipeSearchState;
}

bool nextPageAvailable(RecipeSearchListResponse? recipeList) {
  if (recipeList != null) {
    final pagination = recipeList.pagination;
    return pagination.currentPage < pagination.totalPages;
  }
  return false;
}

@riverpod
class RecipeSearchController extends _$RecipeSearchController {
  @override
  Future<RecipeSearchState> build() async {
    // state = const ;
    final filterSettings = ref.read(recipeSearchFilterSettingsProvider);
    final asyncState = await AsyncValue.guard(() async {
      return await _loadRecipes(
          query: "", page: 1, filterSettings: filterSettings);
    });

    if (asyncState.hasValue) {
      return asyncState.value!;
    }
    return RecipeSearchState(currentQuery: "", recipeList: null);
  }

  Future<RecipeSearchState> _loadRecipes(
      {required String query,
      required int page,
      required FilterSettingsState filterSettings}) async {
    final catmap = await ref.read(staticRepositoryProvider).getCategories();
    final mapcat = catmap.asMap();

    final ret = await ref.read(recipeRepositoryProvider).searchRecipes(
          query,
          // pagination related
          // page: page,
          // pageSize: filterSettings.pageSize,
          // query related
          // lcFilter: filterSettings.lcFilter.toList(),
          categories:
              filterSettings.categories.map((e) => mapcat[e]!.name).toList(),
          // favoritesOnly: filterSettings.favoritesOnly,

          // searchFields: filterSettings.searchFields
          //     .map<String>((e) => API_RECIPE_SEARCH_FIELDS[e]!.left)
          //     .toList(),
          // user: filterSettings.filterOwner ? "owner" : null
        );
    return RecipeSearchState(currentQuery: "", recipeList: ret);
  }

  void searchRecipes(String query) async {
    // get and watch current recipeFilterSettings
    final filterSettings = ref.watch(recipeSearchFilterSettingsProvider);

    // Set the state to loading
    state = const AsyncValue.loading();

    // Add the new todo and reload the todo list from the remote repository
    state = await AsyncValue.guard(() async {
      return await _loadRecipes(
          query: query, page: 1, filterSettings: filterSettings);
    });
  }

  void loadNextRecipePage() async {
    final filterSettings = ref.watch(recipeSearchFilterSettingsProvider);

    if (nextPageAvailable(state.value!.recipeList)) {
      // state = const AsyncValue.loading();
      final ret = await AsyncValue.guard(() async {
        return await _loadRecipes(
            query: state.value!.currentQuery,
            page: state.value!.recipeList!.pagination.currentPage + 1,
            filterSettings: filterSettings);
      });

      ret.when(
        data: (data) {
          // We create a new state from the latest response as to have the updated pagination
          // but we genearte the complete list of results
          final newRecipeList = ret.value!.recipeList!.copyWith(results: [
            ...state.value!.recipeList!.results,
            ...ret.value!.recipeList!.results
          ]);
          state = AsyncData(state.value!.copyWith(recipeList: newRecipeList));
        },
        error: ((error, stackTrace) {
          state = AsyncError(error, stackTrace);
        }),
        loading: (() {
          // state = const AsyncValue.loading();
        }),
      );
    }
  }
}
