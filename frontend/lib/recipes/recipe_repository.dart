// import 'dart:async';
// import 'dart:convert';

// import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:zest/api/responses/pagination.dart';
// import 'package:zest/api/responses/responses.dart';
// import 'package:zest/core/cache/cache_providers.dart';
// import 'package:zest/core/providers/http_client_provider.dart';

// import '../../../core/cache/cache_manager.dart';
// import '../../../core/cache/cache_entry.dart';
// import '../../../core/cache/cache_strategy.dart';
// import '../../../core/network/http_client.dart';
// import '../../../core/network/api_response.dart';

// import 'package:zest/recipes/models/recipe_list_item.dart';

// import 'models/recipe.dart';

// part 'recipe_repository.g.dart';

// class RecipeRepository {
//   final ApiHttpClient _client;
//   final CacheManager<RecipeListItem> _listCache;
//   final CacheManager<Recipe> _fullRecipeCache;

//   RecipeRepository({
//     required ApiHttpClient client,
//     required CacheManager<RecipeListItem> listCache,
//     required CacheManager<Recipe> fullRecipeCache,
//   })  : _client = client,
//         _listCache = listCache,
//         _fullRecipeCache = fullRecipeCache;

//   /// Fetch all recipes from API using pagination internally
//   ///
//   /// Strategy: Cache individual items as flat list, pagination is internal only
//   /// SAFE: Never deletes cache until new data is successfully fetched
//   Future<List<RecipeListItem>> getAllRecipes({
//     bool forceRefresh = false,
//   }) async {
//     // Check if we have cached items and they're not expired
//     final cached = await _listCache.getAll();
//     if (cached.isNotEmpty && !forceRefresh) {
//       // Check if first item is still valid
//       if (!cached.first.isExpired(_listCache.config.ttl)) {
//         return cached.map((e) => e.data).toList()
//           ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
//       }
//     }

//     // Fetch all pages from API
//     final allRecipes = <RecipeListItem>[];
//     final now = DateTime.now();
//     int page = 1;
//     bool hasMore = true;

//     try {
//       while (hasMore) {
//         final paginatedResponse = await _client.get<RecipeListResponse>(
//           '/recipes',
//           RecipeListResponse.fromJson,
//           queryParams: {'page': page, 'page_size': 200},
//         );

//         await paginatedResponse.when(
//           success: (data, statusCode, headers) async {
//             // Store items in memory first (don't persist yet)
//             allRecipes
//                 .addAll(data!.results.map((e) => RecipeListItem.fromRecipe(e)));

//             // Check if there are more pages
//             hasMore = data.pagination.currentPage < data.pagination.totalPages;
//             page++;
//           },
//           failure: (error) {
//             // On error, stop pagination
//             hasMore = false;
//             throw error;
//           },
//         );
//       }

//       // SUCCESS: We fetched all pages without error
//       // Now atomically replace cache with new data

//       // Step 1: Cache all new items with current timestamp
//       for (final item in allRecipes) {
//         final entry = CacheEntry(
//           key: 'recipe_${item.id}',
//           data: item,
//           cachedAt: now,
//           itemTimestamp: item.updatedAt,
//         );
//         await _listCache.put(entry);
//       }

//       // Step 2: Remove stale items (items not in new fetch)
//       final newIds = allRecipes.map((r) => r.id).toSet();
//       for (final oldEntry in cached) {
//         if (!newIds.contains(oldEntry.data.id)) {
//           await _listCache.remove('recipe_${oldEntry.data.id}');
//         }
//       }

//       // Return sorted by creation date (newest first)
//       allRecipes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
//       return allRecipes;
//     } catch (e) {
//       // If error and we have cached data, return it (cache preserved!)
//       if (cached.isNotEmpty) {
//         return cached.map((e) => e.data).toList()
//           ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
//       }
//       rethrow;
//     }
//   }

//   /// Get full recipe with background refresh
//   ///
//   /// Strategy: Show cached immediately, refresh in background
//   /// SAFE: Cache only replaced after successful fetch
//   Future<Recipe> getRecipeById(int id, {bool forceRefresh = false}) async {
//     final key = 'recipe_full_$id';

//     return _fullRecipeCache
//         .fetch(
//       key: key,
//       fetcher: () async {
//         final response =
//             await _client.get<Recipe>("/recipes/$id", Recipe.fromJson);

//         return response.when(
//           success: (data, statusCode, headers) {
//             return data!;
//           },
//           failure: (error) => throw error,
//         );
//       },
//       forceRefresh: forceRefresh,
//     )
//         .then((recipe) {
//       return recipe;
//     });
//   }

//   Future<List<RecipeListItem>> loadMoreRecipes(int currentCount) async {
//     final page = (currentCount ~/ 100) + 1;

//     final response = await _client.get<Map<String, dynamic>>(
//       '/api/v1/recipes',
//       queryParams: {'page': page, 'page_size': 100},
//     );

//     return response.when(
//       success: (data, statusCode, headers) async {
//         final paginatedResponse = PaginatedResponse<RecipeListItem>.fromJson(
//           data!,
//           (json) => RecipeListItem.fromJson(json as Map<String, dynamic>),
//         );

//         // Cache new items
//         for (final item in paginatedResponse.results) {
//           final entry = CacheEntry(
//             key: 'recipe_${item.id}',
//             data: item,
//             cachedAt: DateTime.now(),
//           );
//           await _listCache.put(entry);
//         }

//         return paginatedResponse.results;
//       },
//       failure: (error) => throw error,
//     );
//   }

//   // /// Create new recipe
//   // /// SAFE: No existing cache to worry about
//   // Future<RecipeFull> createRecipe(Map<String, dynamic> recipeData) async {
//   //   final response = await _client.post<Map<String, dynamic>>(
//   //     '/api/v1/recipes',
//   //     body: recipeData,
//   //   );

//   //   return response.when(
//   //     success: (data, statusCode, headers) async {
//   //       // Cache the new recipe
//   //       final id = data!['id'] as int;
//   //       final key = 'recipe_full_$id';

//   //       final entry = CacheEntry(
//   //         key: key,
//   //         data: jsonEncode(data),
//   //         cachedAt: DateTime.now(),
//   //       );
//   //       await _fullRecipeCache.put(entry);

//   //       // Also cache list item
//   //       final listItem = RecipeListItem.fromFullRecipe(data);
//   //       await _listCache.put(
//   //         CacheEntry(
//   //           key: 'recipe_${listItem.id}',
//   //           data: listItem,
//   //           cachedAt: DateTime.now(),
//   //         ),
//   //       );

//   //       return RecipeFull(id: id, rawJson: data, cachedAt: DateTime.now());
//   //     },
//   //     failure: (error) => throw error,
//   //   );
//   // }

//   // /// Update recipe
//   // /// SAFE: Only updates cache after successful network update
//   // Future<RecipeFull> updateRecipe(
//   //   int id,
//   //   Map<String, dynamic> recipeData,
//   // ) async {
//   //   final response = await _client.put<Map<String, dynamic>>(
//   //     '/api/v1/recipes/$id',
//   //     body: recipeData,
//   //   );

//   //   return response.when(
//   //     success: (data, statusCode, headers) async {
//   //       // SUCCESS: Only now update cache
//   //       final key = 'recipe_full_$id';

//   //       final entry = CacheEntry(
//   //         key: key,
//   //         data: jsonEncode(data),
//   //         cachedAt: DateTime.now(),
//   //       );
//   //       await _fullRecipeCache.put(entry);

//   //       // Update list cache
//   //       final listItem = RecipeListItem.fromFullRecipe(data!);
//   //       await _listCache.put(
//   //         CacheEntry(
//   //           key: 'recipe_${listItem.id}',
//   //           data: listItem,
//   //           cachedAt: DateTime.now(),
//   //         ),
//   //       );

//   //       return RecipeFull(id: id, rawJson: data, cachedAt: DateTime.now());
//   //     },
//   //     failure: (error) {
//   //       // FAILURE: Cache unchanged, error propagates
//   //       throw error;
//   //     },
//   //   );
//   // }

//   // /// Force refresh a recipe from network
//   // /// SAFE: forceRefresh in CacheManager only updates after successful fetch
//   // Future<RecipeFull> refreshRecipe(int id) async {
//   //   final key = 'recipe_full_$id';

//   //   return _fullRecipeCache
//   //       .fetch(
//   //     key: key,
//   //     fetcher: () async {
//   //       final response = await _client.get<Map<String, dynamic>>(
//   //         '/api/v1/recipes/$id',
//   //       );

//   //       return response.when(
//   //         success: (data, statusCode, headers) => jsonEncode(data),
//   //         failure: (error) => throw error,
//   //       );
//   //     },
//   //     forceRefresh: true,
//   //   )
//   //       .then((jsonString) {
//   //     return RecipeFull(
//   //       id: id,
//   //       rawJson: jsonDecode(jsonString),
//   //       cachedAt: DateTime.now(),
//   //     );
//   //   });
//   // }

//   /// Search cached recipes
//   Future<List<RecipeListItem>> searchCached(String query) async {
//     final allCached = await _listCache.getAll();

//     if (query.isEmpty) {
//       return allCached.map((e) => e.data).toList()
//         ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
//     }

//     final lowerQuery = query.toLowerCase();

//     return allCached
//         .where((entry) {
//           final title = entry.data.title.toLowerCase();
//           final subtitle = entry.data.subtitle?.toLowerCase() ?? '';
//           return title.contains(lowerQuery) || subtitle.contains(lowerQuery);
//         })
//         .map((e) => e.data)
//         .toList()
//       ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
//   }

//   // /// Filter cached recipes by difficulty
//   // Future<List<RecipeListItem>> filterByDifficulty(int difficulty) async {
//   //   final allCached = await _listCache.getAll();

//   //   return allCached
//   //       .where((entry) => entry.data.difficulty == difficulty)
//   //       .map((e) => e.data)
//   //       .toList()
//   //     ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
//   // }

//   // /// Filter cached recipes by cooking time range
//   // Future<List<RecipeListItem>> filterByCookTime({
//   //   int? minMinutes,
//   //   int? maxMinutes,
//   // }) async {
//   //   final allCached = await _listCache.getAll();

//   //   return allCached
//   //       .where((entry) {
//   //         final cookTime = entry.data.cookTime;
//   //         if (cookTime == null) return false;

//   //         if (minMinutes != null && cookTime < minMinutes) return false;
//   //         if (maxMinutes != null && cookTime > maxMinutes) return false;

//   //         return true;
//   //       })
//   //       .map((e) => e.data)
//   //       .toList()
//   //     ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
//   // }

//   /// Get cache statistics
//   Future<CacheSyncStats> getCacheStats() async {
//     final cached = await _listCache.getAll();

//     if (cached.isEmpty) {
//       return CacheSyncStats(
//         totalItems: 0,
//         // lastSyncType: null,
//         lastUpdatedAt: null,
//         oldestUpdatedAt: null,
//         cacheAge: null,
//       );
//     }

//     final lastUpdatedAt = _findLatestUpdatedAt(cached);
//     final oldestUpdatedAt = _findOldestUpdatedAt(cached);
//     // final lastSyncType = cached.first.metadata?['sync_type'] as String?;
//     final cacheAge = cached.first.age;

//     return CacheSyncStats(
//       totalItems: cached.length,
//       // lastSyncType: lastSyncType,
//       lastUpdatedAt: lastUpdatedAt,
//       oldestUpdatedAt: oldestUpdatedAt,
//       cacheAge: cacheAge,
//     );
//   }

//   DateTime? _findOldestUpdatedAt(List<CacheEntry<RecipeListItem>> cached) {
//     if (cached.isEmpty) return null;

//     DateTime? oldest;
//     for (final entry in cached) {
//       final updatedAt = entry.data.updatedAt;
//       if (oldest == null || updatedAt.isBefore(oldest)) {
//         oldest = updatedAt;
//       }
//     }
//     return oldest;
//   }

//   DateTime? _findLatestUpdatedAt(List<CacheEntry<RecipeListItem>> cached) {
//     if (cached.isEmpty) return null;

//     DateTime? oldest;
//     for (final entry in cached) {
//       final updatedAt = entry.data.updatedAt;
//       if (oldest == null || updatedAt.isAfter(oldest)) {
//         oldest = updatedAt;
//       }
//     }
//     return oldest;
//   }

//   /// Check if incremental sync is recommended
//   /// Returns true if we have cache and it's not too old
//   Future<bool> shouldUseIncrementalSync() async {
//     final cached = await _listCache.getAll();

//     if (cached.isEmpty) return false;

//     // Don't use incremental if cache is very old (> 7 days)
//     // Better to do full sync to ensure consistency
//     final cacheAge = cached.first.age;
//     if (cacheAge > const Duration(days: 7)) return false;

//     return true;
//   }
// }

// /// Cache sync statistics
// class CacheSyncStats {
//   final int totalItems;
//   // final String? lastSyncType; // 'full' or 'incremental'
//   final DateTime? lastUpdatedAt;
//   final DateTime? oldestUpdatedAt;
//   final Duration? cacheAge;

//   CacheSyncStats({
//     required this.totalItems,
//     // required this.lastSyncType,
//     required this.lastUpdatedAt,
//     required this.oldestUpdatedAt,
//     required this.cacheAge,
//   });

//   @override
//   String toString() {
//     return 'CacheSyncStats('
//         'items: $totalItems, '
//         // 'lastSync: $lastSyncType, '
//         'newest: $lastUpdatedAt, '
//         'oldest: $oldestUpdatedAt, '
//         'age: $cacheAge'
//         ')';
//   }
// }

// @Riverpod(keepAlive: true)
// RecipeRepository recipeRepository(Ref ref) {
//   return RecipeRepository(
//     client: ref.watch(apiClientProvider),
//     listCache: ref.watch(recipeListCacheManagerProvider),
//     fullRecipeCache: ref.watch(recipeFullCacheManagerProvider),
//   );
// }

// @riverpod
// class RecipesList extends _$RecipesList {
//   int _currentPage = 0;
//   bool _hasMore = true;

//   late final _pageSize;

//   @override
//   Future<List<RecipeListItem>> build(int pageSize) async {
//     _pageSize = pageSize;
//     return _loadPage(1);
//   }

//   Future<List<RecipeListItem>> _loadPage(int page) async {
//     final repo = ref.read(recipeRepositoryProvider);

//     try {
//       final response = await repo.getRecipes(page: page, pageSize: _pageSize);

//       _currentPage = page;
//       _hasMore =
//           response.pagination.currentPage < response.pagination.totalPages;

//       return response.results;
//     } catch (e) {
//       // If error and we have no data, search cache
//       if (state.value == null || state.value!.isEmpty) {
//         final cached = await repo.searchCached('');
//         if (cached.isNotEmpty) {
//           return cached.take(20).toList();
//         }
//       }
//       rethrow;
//     }
//   }

//   /// Load next page for infinite scroll
//   Future<void> loadMore() async {
//     if (!_hasMore || state.isLoading) return;

//     final currentItems = state.value ?? [];
//     final nextPage = _currentPage + 1;

//     state = const AsyncLoading<List<RecipeListItem>>().copyWithPrevious(state);

//     state = await AsyncValue.guard(() async {
//       final newItems = await _loadPage(nextPage);
//       return [...currentItems, ...newItems];
//     });
//   }

//   /// Refresh from network
//   Future<void> refresh() async {
//     state = const AsyncLoading();
//     state = await AsyncValue.guard(() => _loadPage(1));
//   }

//   /// Search in cached recipes
//   Future<void> searchCached(String query) async {
//     if (query.isEmpty) {
//       await refresh();
//       return;
//     }

//     final repo = ref.read(recipeRepositoryProvider);
//     state = const AsyncLoading();

//     state = await AsyncValue.guard(() async {
//       return repo.searchCached(query);
//     });
//   }
// }
