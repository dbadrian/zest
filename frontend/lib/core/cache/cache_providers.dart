import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/recipes/models/models.dart';
import 'package:zest/recipes/models/recipe_list_item.dart';
import '../cache/persistent_cache.dart';
import '../cache/cache_manager.dart';
import '../cache/cache_strategy.dart';

part 'cache_providers.g.dart';

/// Persistent cache singleton
@Riverpod(keepAlive: true)
PersistentCache persistentCache(Ref ref) {
  final cache = PersistentCache();

  // Initialize on first access
  cache.init();

  // Cleanup on dispose
  ref.onDispose(() => cache.close());

  return cache;
}

/// Recipe list items cache manager
@Riverpod(keepAlive: true)
CacheManager<RecipeListItem> recipeListCacheManager(Ref ref) {
  return CacheManager<RecipeListItem>(
    tableName: 'recipe_list_items',
    config: CacheConfig.dynamicResource,
    decoder: (json) => RecipeListItem.fromJson(json),
    encoder: (item) => item.toJson(),
    persistentCache: ref.watch(persistentCacheProvider),
  );
}

/// Full recipes cache manager (stores raw JSON)
@Riverpod(keepAlive: true)
CacheManager<Recipe> recipeFullCacheManager(Ref ref) {
  return CacheManager<Recipe>(
    tableName: 'recipe_full',
    config: CacheConfig.dynamicResource,
    decoder: (json) => Recipe.fromJson(json),
    encoder: (recipe) => recipe.toJson(),
    persistentCache: ref.watch(persistentCacheProvider),
  );
}
