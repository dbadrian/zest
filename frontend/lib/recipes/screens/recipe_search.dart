import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/config/zest_api.dart';
import 'package:zest/core/network/api_exception.dart';
import 'package:zest/recipes/static_data_repository.dart';

import 'package:zest/ui/login_screen.dart';

import '../controller/search_controller.dart';
import '../models/recipe_category.dart';
import 'recipe_details.dart';
import 'recipe_list_tile.dart';

class RecipeSearchPage<T> extends ConsumerStatefulWidget {
  const RecipeSearchPage({super.key});

  static String get routeName => 'recipes';
  static String get routeLocation => '/recipes';

  @override
  RecipeSearchPageState createState() => RecipeSearchPageState();
}

class RecipeSearchPageState<T> extends ConsumerState<RecipeSearchPage<T>> {
  final TextEditingController _queryTextController =
      TextEditingController(text: "");
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // controller that will be used to load the next page
    _scrollController.addListener(() async {
      if (_scrollController.offset ==
          _scrollController.position.maxScrollExtent) {
        // TODO: Invisible scroll as in old version
        ref.read(recipeSearchControllerProvider.notifier).loadNextRecipePage();
      }
    });
  }

  @override
  void dispose() {
    _queryTextController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // void _onScroll() {
  //   if (_isBottom) {
  //     ref.read(recipesListProvider.notifier).loadMore();
  //   }
  // }

  Widget buildLeading() {
    // final NavigatorState? navigator = Navigator.maybeOf(context);
    // if (navigator != null && navigator.canPop()) {
    //   return IconButton(
    //     icon: const Icon(Icons.arrow_back_ios_new_rounded),
    //     onPressed: () {
    //       context.go(HomePage.routeLocation);
    //       ref.read(recipeSearchControllerProvider.notifier).searchRecipes("");
    //     },
    //   );
    // } else {
    //   return const SizedBox(
    //     width: 10,
    //   );
    // }
    // return const SizedBox(
    //   width: 10,
    // );

    // styling is controlled by theme
    return const Icon(Icons.search);
  }

  List<Widget> buildActions({bool showDelete = false}) {
    return [
      if (showDelete)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            if (_queryTextController.text.isEmpty) {
              // close(context, "");
            } else {
              _queryTextController.text = '';
              ref
                  .read(recipeSearchControllerProvider.notifier)
                  .searchRecipes("");
            }
          },
        ),
      IconButton(
        icon: const Icon(Icons.tune),
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            builder: (BuildContext context) {
              return const FilterSettingsBottomWindow();
            },
          );
          // _showFiltersDialog();
        },
      ),
    ];
  }

  Widget buildBody() {
    final recipeList = ref.watch(recipeSearchControllerProvider);

    // return recipeList.when(
    //   data: (recipeList) =>
    //       Text("loaded recipes ${recipeList.recipeList?.recipes.length}"),
    //   error: (err, stack) => Text("got err"),
    //   loading: () => Center(child: CircularProgressIndicator()),
    // );

    return recipeList.when(
        // show progress indicator
        loading: (() {
      return const Center(child: CircularProgressIndicator());
    }), data: ((state) {
      final recipes = state.recipeList?.results;
      if (recipes == null || recipes.isEmpty) {
        return const ListTile(
            leading: Icon(Icons.manage_search),
            title: Text("No recipes found, try again or changing the filters"));
      } else {
        return RefreshIndicator(
          onRefresh: () async {
            ref
                .read(recipeSearchControllerProvider.notifier)
                .searchRecipes(_queryTextController.text);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            // +1 for circular progress indicator but only if there are more pages to load
            //
            shrinkWrap: true,
            // separatorBuilder: ((context, index) => const Divider()),
            itemCount: recipes.length + 1,
            itemBuilder: (context, index) {
              if (index < recipes.length) {
                final item = recipes[index];
                return RecipeListTile(
                  title: item.title,
                  subtitle: item.subtitle,
                  totalTime: 0,
                  prepTime: item.prepTime,
                  cookTime: item.cookTime,
                  difficulty: item.difficulty,
                  language: item.language,
                  categories: item.categories,
                  isFavorite: item.isFavorited,
                  isDraft: item.isDraft,
                  onTap: () {
                    context.goNamed(
                      RecipeDetailsPage.routeName,
                      pathParameters: {'id': item.id.toString()},
                    );
                  },
                  isAlt: index.isOdd,
                  isHighlighted: false,
                );
              } else {
                if (nextPageAvailable(state.recipeList)) {
                  return const Padding(
                    // TODO: Improve styling
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else {
                  return const ListTile(
                      leading: Icon(Icons.double_arrow),
                      title: Text("No more results..."));
                }
              }
            },
          ),
        );
      }
    }), error: ((error, stackTrace) {
      if (error is ApiException) {
        // Force push to the login page
        // Normally this shouldn't happen too often, thus that is perfectly
        // acceptable
        context.goNamed(LoginPage.routeName);
        return Container();
      } else {
        return ListTile(
          leading: const Icon(Icons.error),
          title: Text("Error: ${error.toString()}."),
        );
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    final numResults = ref.watch(recipeSearchControllerProvider
        .select((state) => state.value?.recipeList?.pagination.total ?? 0));
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          children: [
            Expanded(
              child: buildBody(),
            ),
            IconTheme(
              data:
                  IconThemeData(color: Theme.of(context).colorScheme.onSurface),
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainer,
                height: 50,
                child: Row(
                  children: [
                    // buildLeading(),
                    Flexible(
                      child: SizedBox(
                        height: 35,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: TextField(
                            controller: _queryTextController,
                            // focusNode: focusNode,
                            // style: widget.delegate.searchFieldStyle ?? theme.textTheme.headline6,
                            // textInputAction: widget.delegate.textInputAction,
                            // keyboardType: widget.delegate.keyboardType,
                            onSubmitted: (String _) {
                              // widget.delegate.showResults(context);
                              // const print("Submitted");
                            },
                            onChanged: (String query) async {
                              ref
                                  .read(recipeSearchControllerProvider.notifier)
                                  .searchRecipes(query);
                            },
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface),
                            cursorColor:
                                Theme.of(context).colorScheme.onSurface,
                            decoration: InputDecoration(
                              // fillColor: Colors.white,
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              // TODO: Hint text could be controlled by the settings?
                              hintText: "Search any recipe...",
                              fillColor:
                                  Theme.of(context).colorScheme.surfaceBright,
                              filled: true, // dont forget this line
                              suffix: Text('$numResults Results'),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: -5, horizontal: 15.0),
                              hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...buildActions(
                        showDelete: _queryTextController.text.isNotEmpty)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterSettingsBottomWindow extends ConsumerWidget {
  const FilterSettingsBottomWindow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(recipeSearchFilterSettingsProvider);
    return ListView(
      // mainAxisAlignment: MainAxisAlignment.center,
      // mainAxisSize: MainAxisSize.min,
      shrinkWrap: true,
      children: <Widget>[
        SizedBox(
          height: 40,
          child: Center(
            child: Text('Recipe Search Filter Settings',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        const Divider(),
        SwitchListTile(
          visualDensity: VisualDensity.compact,
          value: settings.favoritesOnly,
          onChanged: ((value) {
            ref
                .read(recipeSearchFilterSettingsProvider.notifier)
                .updateFavoritesOnly(value);
          }),
          secondary: const Icon(Icons.favorite),
          title: const Text('Favorites Only'),
          subtitle: const Text('Only your favorites will be shown!'),
        ),
        const Divider(),
        FutureBuilder(
          future: ref.watch(staticRepositoryProvider).getCategories(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            return FormBuilderFilterChip(
              name: "categories",
              showCheckmark: false,
              initialValue: ref.watch(recipeSearchFilterSettingsProvider
                  .select((s) => s.categories)),
              spacing: 10,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.end,
              runSpacing: 10,
              decoration: const InputDecoration(
                // contentPadding: EdgeInsets.only(bottom: -5, top: 19),
                // labelText: "What categories does this recipe belong to?",
                isDense: false,
                // enabledBorder: InputBorder.none,
                border: OutlineInputBorder(borderSide: BorderSide.none),
                // contentPadding: const EdgeInsets.fromLTRB(0, 0, 12, 24),
              ),
              selectedColor: Theme.of(context).colorScheme.secondaryContainer,
              options: snapshot.data!
                  .map<FormBuilderChipOption<int>>(
                    (RecipeCategory e) => FormBuilderChipOption<int>(
                      value: e.id,
                      child: Text(
                        e.name,
                      ),
                    ),
                  )
                  .toList(),
              //      ??
              // List<FormBuilderChipOption<int>>.empty(),
              // validator: emptyListValidator,
              onChanged: ((c) => ref
                  .read(recipeSearchFilterSettingsProvider.notifier)
                  .updateCategories(c!)),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            );
          },
        ),
        const Divider(),
        SwitchListTile(
          visualDensity: VisualDensity.compact,
          value: settings.filterOwner,
          onChanged: (bool? value) {
            ref
                .read(recipeSearchFilterSettingsProvider.notifier)
                .updateFilterOwner(value!);
          },
          secondary: const Icon(Icons.private_connectivity),
          title: const Text('Private Only'),
          subtitle: const Text('Only recipes created by you will be shown!'),
        ),
        const Divider(),
        SwitchListTile(
          visualDensity: VisualDensity.compact,
          value: settings.showAllLanguages,
          onChanged: ((value) => ref
              .read(recipeSearchFilterSettingsProvider.notifier)
              .updateShowAllLanguages(value)),
          secondary: const Icon(Icons.language),
          title: const Text('All languages'),
          subtitle: const Text('Recipes from all languages will be shown!'),
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 40,
              child: Center(
                child: Text('Search Fields:',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            Flexible(
              fit: FlexFit.tight,
              child: FormBuilderCheckboxGroup<String>(
                visualDensity: VisualDensity.compact,
                name: "search_fields",
                decoration: const InputDecoration(border: InputBorder.none),
                initialValue: settings.searchFields,
                options: API_RECIPE_SEARCH_FIELDS.entries
                    .map<FormBuilderFieldOption<String>>(
                        (e) => FormBuilderFieldOption(value: e.key))
                    .toList(),
                onChanged: ((value) {
                  ref
                      .read(recipeSearchFilterSettingsProvider.notifier)
                      .updateSearchFields(value!);
                }),
                wrapAlignment: WrapAlignment.center,
              ),
            ),
          ],
        ),
        // ListTile(
        //   visualDensity: VisualDensity.compact,
        //   leading: const Icon(Icons.search),
        //   title:
        //   subtitle: const Text(
        //       'Will search in all selected fields for matching terms; if none selected, will search in all fields.'),
        // ),

        // FIXME: This was once the correct way of doing it.
        // ListTile(
        //   visualDensity: VisualDensity.compact,
        //   leading: const Icon(Icons.search),
        //   title: Row(
        //     children: [
        //       // const Text('Search Fields:'),
        //       Expanded(
        //         child: FormBuilderCheckboxGroup<String>(
        //           visualDensity: VisualDensity.compact,
        //           name: "search_fields",
        //           decoration: const InputDecoration(border: InputBorder.none),
        //           initialValue: settings.searchFields,
        //           options: API_RECIPE_SEARCH_FIELDS.entries
        //               .map<FormBuilderFieldOption<String>>(
        //                   (e) => FormBuilderFieldOption(value: e.key))
        //               .toList(),
        //           onChanged: ((value) {
        //             ref
        //                 .read(recipeSearchFilterSettingsProvider.notifier)
        //                 .updateSearchFields(value!);
        //           }),
        //           wrapAlignment: WrapAlignment.center,
        //         ),
        //       ),
        //     ],
        //   ),
        //   subtitle: const Text(
        //       'Will search in all selected fields for matching terms; if none selected, will search in all fields.'),
        // ),
      ],
    );
  }
}
