import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/api/api_service.dart';
import 'package:zest/recipes/models/models.dart';

import '../../../core/cache/cache_manager.dart';
import '../../../core/cache/cache_entry.dart';
import '../../../core/network/http_client.dart';

part 'static_data_repository.g.dart';

/// Repository for static data (units, categories) and semi-static data (foods)
class StaticDataRepository {
  final APIService _client;
  // final CacheManager<Unit> _unitsCache;
  // final CacheManager<RecipeCategory> _categoriesCache;
  // final CacheManager<Food> _foodsCache;

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
    final units = await _client.getRecipeUnits();
    return units.results;
  }

  Future<List<RecipeCategory>> getCategories({
    bool forceRefresh = false,
  }) async {
    final categories = await _client.getRecipeCategories();
    return categories.results;
  }

  Future<List<RecipeCategory>> getFoods({
    bool forceRefresh = false,
  }) async {
    final categories = await _client.getRecipeCategories();
    return categories.results;
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
