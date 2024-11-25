import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/authentication/auth_service.dart';
import 'package:zest/recipes/controller/draft_controller.dart';
import 'package:zest/recipes/screens/recipe_edit.dart';
import 'package:zest/ui/login_screen.dart';

import 'recipe_list_tile.dart';

class RecipeDraftPage<T> extends ConsumerStatefulWidget {
  const RecipeDraftPage({super.key});

  static String get routeName => 'drafts';
  static String get routeLocation => '/drafts';

  @override
  RecipeDraftPageState createState() => RecipeDraftPageState();
}

class RecipeDraftPageState<T> extends ConsumerState<RecipeDraftPage<T>> {
  final TextEditingController _queryTextController =
      TextEditingController(text: "");
  final controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // // controller that will be used to load the next page
    // controller.addListener(() async {
    //   if (controller.offset == controller.position.maxScrollExtent) {
    //     // TODO: Invisible scroll as in old version
    //     ref.read(recipeSearchControllerProvider.notifier).loadNextRecipePage();
    //   }
    // });
  }

  @override
  void dispose() {
    _queryTextController.dispose();
    controller.dispose();
    super.dispose();
  }

  Widget buildLeading() {
    return const Icon(Icons.search);
  }

  List<Widget> buildActions({bool showDelete = false}) {
    return [
      if (showDelete)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            // if (_queryTextController.text.isEmpty) {
            //   // close(context, "");
            // } else {
            //   _queryTextController.text = '';
            //   ref
            //       .read(recipeSearchControllerProvider.notifier)
            //       .searchRecipes("");
            // }
          },
        ),
    ];
  }

  Widget buildBody() {
    final recipeList = ref.watch(recipeDraftSearchControllerProvider);
    return recipeList.when(data: ((state) {
      final recipes = state.recipeDraftList;
      if (recipes.isEmpty) {
        return const ListTile(
            leading: Icon(Icons.manage_search),
            title: Text("No drafts found!"));
      } else {
        return RefreshIndicator(
          onRefresh: () async {
            ref.read(recipeDraftSearchControllerProvider.notifier).reload();
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: controller,
            // +1 for circular progress indicator but only if there are more pages to load
            //
            shrinkWrap: true,
            // separatorBuilder: ((context, index) => const Divider()),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final item = recipes.entries.toList()[index];
              final prepTime = int.tryParse(item.value.prepTime);
              final cookTime = int.tryParse(item.value.cookTime);
              return RecipeListTile(
                title: item.value.title.isEmpty
                    ? "Untitled Draft"
                    : item.value.title,
                subtitle: item.value.subtitle,
                totalTime: (prepTime ?? 0) + (cookTime ?? 0),
                prepTime: int.tryParse(item.value.prepTime),
                cookTime: int.tryParse(item.value.cookTime),
                difficulty: item.value.difficulty,
                isAlt: index.isOdd,
                isHighlighted: false,
                onDelete: () {
                  ref
                      .read(recipeDraftSearchControllerProvider.notifier)
                      .deleteDraft(item.key);
                },
                onTap: () {
                  context.goNamed(
                    RecipeEditPage.routeNameDraftEdit,
                    pathParameters: {'draftId': item.key.toString()},
                  );
                },
              );
            },
          ),
        );
      }
    }), error: ((error, stackTrace) {
      if (error is AuthException) {
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
    }), loading: (() {
      return const Center(child: CircularProgressIndicator());
    }));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: ref
                  .watch(recipeDraftSearchControllerProvider)
                  .value
                  ?.recipeDraftList
                  .isEmpty ??
              true
          ? null
          : FloatingActionButton.small(
              foregroundColor: colorScheme.onSecondaryContainer,
              backgroundColor: colorScheme.secondaryContainer,
              onPressed: () async {
                return showDialog<void>(
                  context: context,
                  barrierDismissible: false, // user must tap button!
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Warning!'),
                      content: const SingleChildScrollView(
                        child: ListBody(
                          children: <Widget>[
                            Text('Would you like to delete ALL drafts?'),
                            Text('Data will be deleted irreversibly!'),
                          ],
                        ),
                      ),
                      actionsAlignment: MainAxisAlignment.spaceEvenly,
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: Text('Delete',
                              style: TextStyle(color: colorScheme.error)),
                          onPressed: () async {
                            ref
                                .read(recipeDraftSearchControllerProvider
                                    .notifier)
                                .deleteAllDrafts();
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Icon(Icons.delete_forever),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          children: [
            Expanded(
              child: buildBody(),
            ),
          ],
        ),
      ),
    );
  }
}
