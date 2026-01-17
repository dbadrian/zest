import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/api/api_service.dart';
import 'package:zest/api/responses/multilingual_data_response.dart';
import 'package:zest/recipes/models/models.dart';

part 'static_data_repository.g.dart';

/// Repository for static data (units, categories) and semi-static data (foods)
class StaticDataRepository {
  final APIService _client;
  // final CacheManager<Unit> _unitsCache;
  // final CacheManager<RecipeCategory> _categoriesCache;
  // final CacheManager<Food> _foodsCache;

  List<Unit>? _units;
  List<RecipeCategory>? _categories;
  List<Food>? _foods;
  MultilingualData? _multilingualData;

  StaticDataRepository({
    required APIService client,
    // required CacheManager<Unit> unitsCache,
    // required CacheManager<RecipeCategory> categoriesCache,
    // required CacheManager<Food> foodsCache,
  }) : _client = client;
  // _unitsCache = unitsCache,
  // _categoriesCache = categoriesCache,
  // _foodsCache = foodsCache;

  Future<List<Unit>> getUnits({bool forceRefresh = false}) async {
    if (_units == null || forceRefresh) {
      final units = await _client.getRecipeUnits();
      // TODO: HIGH Handle APIException
      _units = units.results;
    }

    return _units!;
  }

  Future<List<RecipeCategory>> getCategories({
    bool forceRefresh = false,
  }) async {
    if (_categories == null || forceRefresh) {
      final categories = await _client.getRecipeCategories();
      // TODO: HIGH  Handle APIException

      _categories = categories.results;
    }

    return _categories!;
  }

  Future<List<Food>> getFoods({
    bool forceRefresh = false,
  }) async {
    if (_foods == null || forceRefresh) {
      final foods = await _client.getRecipeFoodCandidates();
      // TODO: HIGH Handle APIException

      _foods = foods.results;
    }

    return _foods!;
  }

  Future<MultilingualData> getMultilingualData({
    bool forceRefresh = false,
  }) async {
    if (_multilingualData == null || forceRefresh) {
      // TODO: HIGH Handle APIException
      _multilingualData = await _client.getMultilingualData();
    }

    return _multilingualData!;
  }

  // Future<List<Unit>> searchUnits(String query) async {
  //   final mld = getMultilingualData();

  //   return Future.value(extractTop<Unit>(
  //       query: query.toLowerCase(),
  //       choices: _units!,
  //       limit: 500,
  //       getter: (x) => x.name.toLowerCase()).map((e) => e.choice).toList());
  // }

  // helper functions
  Future<List<Food>> searchFoods(
    String query, {
    List<String>? languageFilter,
    bool onlineFirst = false,
  }) async {
    // check online status
    if (onlineFirst) {
      // TODO: HIGH Handle APIException
      final ret = await AsyncValue.guard(
          () => _client.searchFoods(query, languages: languageFilter));

      return ret.when(
        data: (data) => data.results,
        error: (error, stackTrace) {
          // TODO: MID return local search
          return [];
        },
        loading: () => [],
      );
    } else {
      // TODO: MID implement some sort of fuzzy search
      return getFoods();
    }
  }
}

@Riverpod(keepAlive: true)
StaticDataRepository staticRepository(Ref ref) {
  return StaticDataRepository(
    client: ref.watch(apiServiceProvider),
    // _unitsCache: ref.watch(recipeListCacheManagerProvider),
    // fullRecipeCache: ref.watch(recipeFullCacheManagerProvider),
  );
}
