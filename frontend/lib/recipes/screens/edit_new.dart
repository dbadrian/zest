import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zest/recipes/controller/details_controller.dart';
import 'package:zest/recipes/controller/edit_providers.dart';
import 'package:zest/recipes/models/models.dart';
import 'package:zest/recipes/models/recipe_draft.dart';
import 'package:zest/recipes/recipe_repository.dart';
import 'package:zest/recipes/screens/recipe_details.dart';
import 'package:zest/recipes/static_data_repository.dart';

class RecipeEditScreen extends ConsumerStatefulWidget {
  static String get routeNameEdit => 'recipe_edit';
  static String get routeNameDraftEdit => 'recipe_draft_edit';
  static String get routeNameCreate => 'recipe_create';

  final int? recipeId;
  final int undoHistoryLimit;
  // final List<String> availableLanguages;
  // final Map<int, String> validCategories;
  // final List<String> units;
  // final List<String> foods;
  // final Future<List<String>> Function(String query) searchUnits;
  // final Future<List<String>> Function(String query) searchFoods;
  // final Future<void> Function(Map<String, dynamic> formData) handleForm;

  const RecipeEditScreen({
    super.key,
    this.recipeId,
    this.undoHistoryLimit = 50,
  });

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusScopeNode();

  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _ownerCommentController = TextEditingController();
  final _sourceNameController = TextEditingController();
  final _sourcePageController = TextEditingController();
  final _sourceUrlController = TextEditingController();

  final _servingsController = TextEditingController();

  // ignore: unused_field
  String? _selectedLanguage = "en";
  bool _isPrivate = false;
  bool _isDraft = false;
  int _difficulty = 3;
  // int? _servings = 4;
  int _prepTimeHours = 0;
  int _prepTimeMinutes = 0;
  int _cookTimeHours = 0;
  int _cookTimeMinutes = 0;
  Set<int> _selectedCategories = {};
  List<InstructionGroupData> _instructionGroups = [InstructionGroupData()];
  List<IngredientGroupData> _ingredientGroups = [IngredientGroupData()];
  bool _isSubmitting = false;

  bool _isLoadingRecipe = false;
  bool _isInitialized = false;

  // Undo/Redo system
  // final List<FormSnapshot> _undoStack = [];
  // final List<FormSnapshot> _redoStack = [];
  // bool _isUndoRedoOperation = false;
  // int _rebuildKey = 0;

  @override
  void initState() {
    super.initState();

    if (widget.recipeId != null) {
      () async {
        setState(() {
          _isLoadingRecipe = true;
        });

        final data = await ref
            .read(recipeRepositoryProvider)
            .getRecipeById(widget.recipeId!);

        setState(() {
          if (data != null) {
            _selectedLanguage = data.language;
            _isDraft = data.isDraft;
            _isPrivate = data.isPrivate;

            _titleController.text = data.latestRevision.title ?? "";
            _subtitleController.text = data.latestRevision.subtitle ?? "";
            _ownerCommentController.text =
                data.latestRevision.ownerComment ?? "";
            _sourceNameController.text = data.latestRevision.sourceName ?? "";
            _sourcePageController.text = data.latestRevision.sourcePage ?? "";
            _sourceUrlController.text = data.latestRevision.sourceUrl ?? "";

            if (data.latestRevision.difficulty != null) {
              _difficulty = data.latestRevision.difficulty!;
            }
            _servingsController.text =
                data.latestRevision.servings?.toString() ?? "";
            if (data.latestRevision.prepTime != null) {
              _prepTimeHours = data.latestRevision.prepTime! ~/ 60;
              _prepTimeMinutes = data.latestRevision.prepTime! % 60;
            }
            if (data.latestRevision.cookTime != null) {
              _cookTimeHours = data.latestRevision.cookTime! ~/ 60;
              _cookTimeMinutes = data.latestRevision.cookTime! % 60;
            }
            _selectedCategories =
                data.latestRevision.categories.map((e) => e.id).toSet();

            _instructionGroups = data.latestRevision.instructionGroups
                .map((e) =>
                    InstructionGroupData.fromData(e.name, e.instructions))
                .toList();

            _ingredientGroups = data.latestRevision.ingredientGroups
                .map((e) => IngredientGroupData.fromData(
                    e.name,
                    e.ingredients
                        .map((i) => Ingredient.fromData(
                            amountMin: i.amountMin?.toString(),
                            amountMax: i.amountMax?.toString(),
                            comment: i.comment,
                            food: i.food,
                            selectedUnit: i.unit,
                            selectedFood: null))
                        .toList()))
                .toList();
          }

          _isLoadingRecipe = false;
          _isInitialized = true;
        });
      }();
    } else {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _ownerCommentController.dispose();
    _sourceNameController.dispose();
    _sourcePageController.dispose();
    _sourceUrlController.dispose();
    _servingsController.dispose();
    for (var group in _instructionGroups) {
      group.dispose();
    }
    for (var group in _ingredientGroups) {
      group.dispose();
    }
    super.dispose();
  }

  void _saveSnapshot() {
    // if (_isUndoRedoOperation) return;

    // final snapshot = FormSnapshot(
    //   title: _titleController.text,
    //   subtitle: _subtitleController.text,
    //   comment: _commentController.text,
    //   selectedLanguage: _selectedLanguage,
    //   isPrivate: _isPrivate,
    //   difficulty: _difficulty,
    //   servings: _servings,
    //   prepTimeHours: _prepTimeHours,
    //   prepTimeMinutes: _prepTimeMinutes,
    //   cookTimeHours: _cookTimeHours,
    //   cookTimeMinutes: _cookTimeMinutes,
    //   sourceName: _sourceNameController.text,
    //   sourcePage: _sourcePageController.text,
    //   sourceUrl: _sourceUrlController.text,
    //   selectedCategories: Set.from(_selectedCategories),
    //   instructionGroups: _instructionGroups.map((g) => g.clone()).toList(),
    //   ingredientGroups: _ingredientGroups.map((g) => g.clone()).toList(),
    // );

    // _undoStack.add(snapshot);
    // debugPrint("Adding on top of stack");
    // if (_undoStack.length > widget.undoHistoryLimit) {
    //   debugPrint("Dropping oldest stack entry");
    //   _undoStack.removeAt(0);
    // }
    // _redoStack.clear();
  }

  // void _undo() {
  //   if (_undoStack.length <= 1) return;

  //   setState(() {
  //     _isUndoRedoOperation = true;

  //     final current = _undoStack.removeLast();
  //     _redoStack.add(current);

  //     final previous = _undoStack.last;
  //     _restoreSnapshot(previous);

  //     _rebuildKey++; // Force widget tree rebuild
  //   });

  //   // Delay resetting flag
  //   Future.microtask(() {
  //     _isUndoRedoOperation = false;
  //   });
  // }

  // void _redo() {
  //   if (_redoStack.isEmpty) return;

  //   _isUndoRedoOperation = true;
  //   final snapshot = _redoStack.removeLast();
  //   _undoStack.add(snapshot);
  //   _restoreSnapshot(snapshot);
  //   _isUndoRedoOperation = false;
  // }

  // void _restoreSnapshot(FormSnapshot snapshot) {
  //   setState(() {
  //     _titleController.text = snapshot.title;
  //     _subtitleController.text = snapshot.subtitle;
  //     _commentController.text = snapshot.comment;
  //     _selectedLanguage = snapshot.selectedLanguage;
  //     _isPrivate = snapshot.isPrivate;
  //     _difficulty = snapshot.difficulty;
  //     _servings = snapshot.servings;
  //     _prepTimeHours = snapshot.prepTimeHours;
  //     _prepTimeMinutes = snapshot.prepTimeMinutes;
  //     _cookTimeHours = snapshot.cookTimeHours;
  //     _cookTimeMinutes = snapshot.cookTimeMinutes;
  //     _sourceNameController.text = snapshot.sourceName;
  //     _sourcePageController.text = snapshot.sourcePage;
  //     _sourceUrlController.text = snapshot.sourceUrl;
  //     _selectedCategories = Set.from(snapshot.selectedCategories);

  //     // Dispose old groups
  //     for (var group in _instructionGroups) {
  //       group.dispose();
  //     }
  //     for (var group in _ingredientGroups) {
  //       group.dispose();
  //     }

  //     _instructionGroups =
  //         snapshot.instructionGroups.map((g) => g.clone()).toList();
  //     _ingredientGroups =
  //         snapshot.ingredientGroups.map((g) => g.clone()).toList();
  //   });
  // }

  // TODO: Use 3rd party here...
  String _getFlagEmoji(String languageCode) {
    final flags = {
      'de': '🇩🇪',
      'en': '🇬🇧',
      'jp': '🇯🇵',
      'es': '🇪🇸',
      'fr': '🇫🇷',
      'it': '🇮🇹',
      'pt': '🇵🇹',
      'ru': '🇷🇺',
      'zh': '🇨🇳',
      'kr': '🇰🇷',
    };
    return flags[languageCode] ?? '🌐';
  }

  // TODO: Get from settings
  String _getLanguageName(String code) {
    final names = {
      'de': 'German',
      'en': 'English',
      'jp': 'Japanese',
      'es': 'Spanish',
      'fr': 'French',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'zh': 'Chinese',
      'kr': 'Korean',
    };
    return names[code] ?? code.toUpperCase();
  }

  Future<bool> _submitForm() async {
    if (!_isDraft && !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix validation errors')),
      );
      return false;
    }

    setState(() => _isSubmitting = true);
    var success = true;

    try {
      final prepTime = _prepTimeHours * 60 + _prepTimeMinutes;
      final cookTime = _cookTimeHours * 60 + _cookTimeMinutes;
      final draft = RecipeDraft(
          language: _selectedLanguage = "en",
          isPrivate: _isPrivate,
          isDraft: _isDraft,
          latestRevision: RecipeRevisionDraft(
              title:
                  _titleController.text.isEmpty ? null : _titleController.text,
              subtitle: _subtitleController.text.isEmpty
                  ? null
                  : _subtitleController.text,
              ownerComment: _ownerCommentController.text.isEmpty
                  ? null
                  : _ownerCommentController.text,
              difficulty: _difficulty,
              servings: int.tryParse(_servingsController.text),
              prepTime: prepTime > 0 ? prepTime : null,
              cookTime: cookTime > 0 ? cookTime : null,
              sourceName: _sourceNameController.text.isEmpty
                  ? null
                  : _sourceNameController.text,
              sourcePage: _sourcePageController.text.isEmpty
                  ? null
                  : _sourcePageController.text,
              sourceUrl: _sourceUrlController.text.isEmpty
                  ? null
                  : _sourceUrlController.text,
              categories: _selectedCategories.toList(),
              instructionGroups:
                  _instructionGroups.map((g) => g.toModel()).toList(),
              ingredientGroups:
                  _ingredientGroups.map((g) => g.toModel()).toList()));

      // TODO: handle the form by uploading via repository.
      // await widget.handleForm(formData);

      if (widget.recipeId == null) {
        final recipe =
            await ref.read(recipeRepositoryProvider).createRecipe(draft);
        if (recipe != null) {
          if (context.mounted) {
            // reopen editor with from the now created recipe
            // such that widget.recipeId is set
            // ignore: use_build_context_synchronously
            context.goNamed(RecipeEditScreen.routeNameEdit,
                pathParameters: {'id': recipe.id.toString()});
          }
        }
      } else {
        ref
            .read(recipeRepositoryProvider)
            .updateRecipe(widget.recipeId!, draft);
      }

      debugPrint(draft.toJson().toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe saved successfully!')),
        );
      }
    } catch (e) {
      success = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    return success;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRecipe) {
      debugPrint("Loading recipe data");
      // TODO: cooler circularprogreesinidicator with text

      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_isInitialized) {
      debugPrint("Still initializing");

      return Center(
        child: CircularProgressIndicator(),
      );
    }

    // load here as we want to watch it e.g. for language changes
    final staticData = ref.watch(recipeStaticDataProvider);

    return staticData.when(
      loading: () {
        debugPrint("Loading static data");
        return Center(
          child: CircularProgressIndicator(),
        );
      },
      error: (error, stackTrace) {
        debugPrint("error...");

        return Center(
          child: Text('ERRRRRRRORRRRRR: $error'),
        );
      },
      data: (data) {
        return KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (event) {
              if (event is KeyDownEvent) {
                final isControlPressed =
                    HardwareKeyboard.instance.isControlPressed ||
                        HardwareKeyboard.instance.isMetaPressed;
                final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

                // // Undo/Redo
                // if (isControlPressed &&
                //     event.logicalKey == LogicalKeyboardKey.keyZ) {
                //   if (isShiftPressed) {
                //     _redo();
                //   } else {
                //     _undo();
                //   }
                // }
                // // Submit form
                // else
                if (isControlPressed &&
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  _submitForm();
                }
                // Add instruction group
                else if (isControlPressed &&
                    isShiftPressed &&
                    event.logicalKey == LogicalKeyboardKey.keyI) {
                  setState(() {
                    _instructionGroups.add(InstructionGroupData());
                  });
                }
                // Add ingredient group
                else if (isControlPressed &&
                    isShiftPressed &&
                    event.logicalKey == LogicalKeyboardKey.keyG) {
                  setState(() {
                    _ingredientGroups.add(IngredientGroupData());
                  });
                }
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWide ? 32 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: isWide ? 1200 : double.infinity),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBasicInfoSection(isWide),
                            const SizedBox(height: 32),
                            _buildMetadataSection(isWide),
                            const SizedBox(height: 32),
                            _buildTimeSection(isWide),
                            const SizedBox(height: 32),
                            _buildSourceSection(isWide),
                            const SizedBox(height: 32),
                            _buildCategoriesSection(data.categories
                                .map((e) => e.copyWith(
                                    name: data.currentLanguageData["categories"]
                                        [e.name]))
                                .toList()),
                            const SizedBox(height: 32),
                            _buildIngredientGroupsSection(data.units,
                                data.foods, data.currentLanguageData),
                            const SizedBox(height: 32),
                            _buildInstructionGroupsSection(),
                            const SizedBox(height: 48),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSubmitButton(),
                                const SizedBox(width: 14),
                                _buildSubmitAndCloseButton(),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ));
      },
    );
  }

  Widget _buildBasicInfoSection(bool isWide) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basic Information',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Title is required' : null,
              onChanged: (_) => _saveSnapshot(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subtitleController,
              decoration: const InputDecoration(
                labelText: 'Subtitle',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveSnapshot(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ownerCommentController,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (_) => _saveSnapshot(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection(bool isWide) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recipe Details',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            if (isWide)
              Row(
                children: [
                  Expanded(child: _buildLanguageDropdown()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildServingsField()),
                ],
              )
            else ...[
              _buildLanguageDropdown(),
              const SizedBox(height: 16),
              _buildServingsField(),
            ],
            const SizedBox(height: 20),
            _buildPrivateCheckbox(),
            const SizedBox(height: 20),
            _buildDraftCheckbox(),
            const SizedBox(height: 20),
            _buildDifficultySelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedLanguage = "en",
      decoration: const InputDecoration(
        labelText: 'Language *',
        border: OutlineInputBorder(),
      ),
      // TODO: Handle the language source on whats supported
      items: ["de", "en", "jp"].map((lang) {
        return DropdownMenuItem(
          value: lang,
          child: Row(
            children: [
              Text(_getFlagEmoji(lang), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(_getLanguageName(lang)),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        setState(() => _selectedLanguage = v);
      },
      validator: (v) => v == null ? 'Language is required' : null,
    );
  }

  Widget _buildServingsField() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            // initialValue: _servings.toString(),
            controller: _servingsController,
            decoration: const InputDecoration(
              labelText: 'Servings',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              final val = int.tryParse(v);
              if (val == null || val < 1 || val > 99) return '1-99';
              return null;
            },
            // onChanged: (v) {
            //   final val = int.tryParse(v);
            //   if (val != null) {
            //     setState(() => _servings = val);
            //   }
            // },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () {
              if (_servingsController.text.isNotEmpty) {
                final val = int.tryParse(_servingsController.text) ?? 0;
                if (val == 1) {
                  _servingsController.text = "";
                } else if (val > 1) {
                  _servingsController.text = (val - 1).toString();
                }
              }
            }),
        IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              if (_servingsController.text.isNotEmpty) {
                final val = int.tryParse(_servingsController.text) ?? 0;
                if (val < 99) {
                  _servingsController.text = (val + 1).toString();
                }
              } else {
                _servingsController.text = "1";
              }
            }),
      ],
    );
  }

  Widget _buildPrivateCheckbox() {
    return CheckboxListTile(
      title: const Text('Private Recipe'),
      subtitle: const Text('Only visible to you'),
      value: _isPrivate,
      onChanged: (v) {
        setState(() => _isPrivate = v ?? false);
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildDraftCheckbox() {
    return CheckboxListTile(
      title: const Text('Draft Recipe'),
      subtitle: const Text('Only visible to you until released'),
      value: _isDraft,
      onChanged: (v) {
        setState(() => _isDraft = v ?? false);
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildDifficultySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Difficulty',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            final level = i + 1;
            return InkWell(
              onTap: () {
                setState(() => _difficulty = level);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  level <= _difficulty ? Icons.star : Icons.star_border,
                  size: 40,
                  color: level <= _difficulty ? Colors.amber : Colors.grey,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTimeSection(bool isWide) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            if (isWide)
              Row(
                children: [
                  Expanded(
                      child: _buildTimeInput(
                          'Prep Time', _prepTimeHours, _prepTimeMinutes, true)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildTimeInput('Cook Time', _cookTimeHours,
                          _cookTimeMinutes, false)),
                ],
              )
            else ...[
              _buildTimeInput(
                  'Prep Time', _prepTimeHours, _prepTimeMinutes, true),
              const SizedBox(height: 16),
              _buildTimeInput(
                  'Cook Time', _cookTimeHours, _cookTimeMinutes, false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInput(String label, int hours, int minutes, bool isPrep) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: hours.toString(),
                decoration: const InputDecoration(
                  labelText: 'Hours',
                  border: OutlineInputBorder(),
                  suffix: Text('h'),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final val = int.tryParse(v);
                  if (val == null || val < 0 || val > 9999) return '0-9999';
                  return null;
                },
                onChanged: (v) {
                  final val = int.tryParse(v) ?? 0;
                  setState(() {
                    if (isPrep) {
                      _prepTimeMinutes = val;
                    } else {
                      _cookTimeMinutes = val;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: minutes.toString(),
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  border: OutlineInputBorder(),
                  suffix: Text('m'),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final val = int.tryParse(v);
                  if (val == null || val < 0 || val > 59) return '0-59';
                  return null;
                },
                onChanged: (v) {
                  final val = int.tryParse(v) ?? 0;
                  setState(() {
                    if (isPrep) {
                      _prepTimeMinutes = val;
                    } else {
                      _cookTimeMinutes = val;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceSection(bool isWide) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source Information',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            TextFormField(
              controller: _sourceNameController,
              onChanged: (_) => _saveSnapshot(),
              decoration: const InputDecoration(
                labelText: 'Source Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sourcePageController,
                      onChanged: (_) => _saveSnapshot(),
                      decoration: const InputDecoration(
                        labelText: 'Source Page',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _sourceUrlController,
                      onChanged: (_) => _saveSnapshot(),
                      decoration: const InputDecoration(
                        labelText: 'Source URL',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v != null &&
                            v.isNotEmpty &&
                            !Uri.tryParse(v)!.hasScheme) {
                          return 'Invalid URL';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              )
            else ...[
              TextFormField(
                controller: _sourcePageController,
                onChanged: (_) => _saveSnapshot(),
                decoration: const InputDecoration(
                  labelText: 'Source Page',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sourceUrlController,
                onChanged: (_) => _saveSnapshot(),
                decoration: const InputDecoration(
                  labelText: 'Source URL',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v != null &&
                      v.isNotEmpty &&
                      !Uri.tryParse(v)!.hasScheme) {
                    return 'Invalid URL';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(List<RecipeCategory> categories) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categories',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSelected = _selectedCategories.contains(cat.id);
                return FilterChip(
                  label: Text(cat.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategories.add(cat.id);
                      } else {
                        _selectedCategories.remove(cat.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionGroupsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Instructions',
                    style: Theme.of(context).textTheme.headlineSmall),
                Tooltip(
                  message: 'Ctrl+Shift+I',
                  child: IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: () {
                      setState(
                          () => _instructionGroups.add(InstructionGroupData()));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _instructionGroups.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _instructionGroups.removeAt(oldIndex);
                  _instructionGroups.insert(newIndex, item);
                });
              },
              itemBuilder: (context, i) {
                return Padding(
                  key: ValueKey('instruction_$i'),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _InstructionGroupWidget(
                    group: _instructionGroups[i],
                    index: i,
                    canMoveUp: i > 0,
                    canMoveDown: i < _instructionGroups.length - 1,
                    onMoveUp: () {
                      setState(() {
                        final item = _instructionGroups.removeAt(i);
                        _instructionGroups.insert(i - 1, item);
                      });
                    },
                    onMoveDown: () {
                      setState(() {
                        final item = _instructionGroups.removeAt(i);
                        _instructionGroups.insert(i + 1, item);
                      });
                    },
                    onRemove: _instructionGroups.length > 1
                        ? () {
                            setState(() => _instructionGroups.removeAt(i));
                          }
                        : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientGroupsSection(List<Unit> units, List<Food> foods,
      Map<String, dynamic> currentLanguageData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ingredients',
                    style: Theme.of(context).textTheme.headlineSmall),
                Tooltip(
                  message: 'Ctrl+Shift+I',
                  child: IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () {
                        setState(
                            () => _ingredientGroups.add(IngredientGroupData()));
                      }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ingredientGroups.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _ingredientGroups.removeAt(oldIndex);
                  _ingredientGroups.insert(newIndex, item);
                });
              },
              itemBuilder: (context, i) {
                return Padding(
                  key: ValueKey('ingredient_group_$i'),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _IngredientGroupWidget(
                    group: _ingredientGroups[i],
                    index: i,
                    units: units,
                    foods: foods,
                    currentLangData: currentLanguageData,
                    searchUnits: (String query) async {
                      final ret = await ref
                          .read(staticRepositoryProvider)
                          .searchUnits(query);
                      return ret;
                    },
                    searchFoods: (String query) async {
                      final ret = await ref
                          .read(staticRepositoryProvider)
                          .searchFoods(query, onlineFirst: true);
                      return ret;
                    },
                    canMoveUp: i > 0,
                    canMoveDown: i < _ingredientGroups.length - 1,
                    onMoveUp: () {
                      setState(() {
                        final item = _ingredientGroups.removeAt(i);
                        _ingredientGroups.insert(i - 1, item);
                      });
                    },
                    onMoveDown: () {
                      setState(() {
                        final item = _ingredientGroups.removeAt(i);
                        _ingredientGroups.insert(i + 1, item);
                      });
                    },
                    onRemove: _ingredientGroups.length > 1
                        ? () {
                            setState(() => _ingredientGroups.removeAt(i));
                          }
                        : null,
                    onReorderIngredients: (oldIdx, newIdx) {
                      setState(() {
                        if (newIdx > oldIdx) newIdx--;
                        final item =
                            _ingredientGroups[i].ingredients.removeAt(oldIdx);
                        _ingredientGroups[i].ingredients.insert(newIdx, item);
                      });
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitForm,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Save', style: TextStyle(fontSize: 18)),
    );
  }

  Widget _buildSubmitAndCloseButton() {
    return ElevatedButton(
      onPressed: _isSubmitting
          ? null
          : () async {
              final success = await _submitForm();

              if (success && widget.recipeId != null) {
                ref.invalidate(
                    RecipeDetailsControllerProvider(widget.recipeId!));
                if (context.mounted) {
                  // ignore: use_build_context_synchronously
                  context.pop();
                  context.goNamed(
                    RecipeDetailsPage.routeName,
                    pathParameters: {'id': widget.recipeId.toString()},
                  );
                }
              }
            },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Save and Close', style: TextStyle(fontSize: 18)),
    );
  }
}

// Snapshot system for undo/redo
class FormSnapshot {
  final String title;
  final String subtitle;
  final String comment;
  final String? selectedLanguage;
  final bool isPrivate;
  final int difficulty;
  final int servings;
  final int prepTimeHours;
  final int prepTimeMinutes;
  final int cookTimeHours;
  final int cookTimeMinutes;
  final String sourceName;
  final String sourcePage;
  final String sourceUrl;
  final Set<int> selectedCategories;
  final List<InstructionGroupData> instructionGroups;
  final List<IngredientGroupData> ingredientGroups;

  FormSnapshot({
    required this.title,
    required this.subtitle,
    required this.comment,
    required this.selectedLanguage,
    required this.isPrivate,
    required this.difficulty,
    required this.servings,
    required this.prepTimeHours,
    required this.prepTimeMinutes,
    required this.cookTimeHours,
    required this.cookTimeMinutes,
    required this.sourceName,
    required this.sourcePage,
    required this.sourceUrl,
    required this.selectedCategories,
    required this.instructionGroups,
    required this.ingredientGroups,
  });
}

class InstructionGroupData {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController textController = TextEditingController();

  InstructionGroupData();

  InstructionGroup toModel() {
    return InstructionGroup(
        name: nameController.text, instructions: textController.text);
  }

  InstructionGroupData.fromData(String? name, String? text) {
    nameController.text = name ?? "";
    textController.text = text ?? "";
  }

  InstructionGroupData clone() {
    return InstructionGroupData.fromData(
        nameController.text, textController.text);
  }

  void dispose() {
    nameController.dispose();
    textController.dispose();
  }
}

class _InstructionGroupWidget extends StatelessWidget {
  final InstructionGroupData group;
  final int index;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback? onRemove;

  const _InstructionGroupWidget({
    required this.group,
    required this.index,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drag_indicator, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Step ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (canMoveUp)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    onPressed: onMoveUp,
                    tooltip: 'Move up',
                  ),
                if (canMoveDown)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    onPressed: onMoveDown,
                    tooltip: 'Move down',
                  ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onRemove,
                    tooltip: 'Remove',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: group.nameController,
              decoration: const InputDecoration(
                labelText: 'Step Title *',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 2) return 'Min 2 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: group.textController,
              decoration: const InputDecoration(
                labelText: 'Instructions *',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Use \\n\\n\\ to separate elements',
              ),
              maxLines: 5,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 2) return 'Min 2 characters';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class IngredientGroupData {
  final TextEditingController nameController = TextEditingController();
  final List<Ingredient> ingredients = [Ingredient()];

  IngredientGroupData();

  IngredientGroupData.fromData(String? name, List<Ingredient> ings) {
    nameController.text = name ?? "";
    ingredients.clear();
    ingredients.addAll(ings);
  }

  IngredientGroupData clone() {
    return IngredientGroupData.fromData(
      nameController.text,
      ingredients.map((i) => i.clone()).toList(),
    );
  }

  IngredientGroupDraft toModel() {
    return IngredientGroupDraft(
        name: nameController.text,
        ingredients: ingredients.map((i) => i.toModel()).toList());
  }

  void dispose() {
    nameController.dispose();
    for (var ing in ingredients) {
      ing.dispose();
    }
  }
}

class Ingredient {
  final TextEditingController amountMinController = TextEditingController();
  final TextEditingController amountMaxController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final TextEditingController foodController = TextEditingController();
  Unit? selectedUnit;
  Food? selectedFood;

  Ingredient();

  Ingredient.fromData({
    required String? amountMin,
    required String? amountMax,
    required String? comment,
    required String? food,
    required this.selectedUnit,
    required this.selectedFood,
  }) {
    amountMinController.text = amountMin ?? "";
    amountMaxController.text = amountMax ?? "";
    commentController.text = comment ?? "";
    foodController.text = food ?? "";
  }

  Ingredient clone() {
    return Ingredient.fromData(
      amountMin: amountMinController.text,
      amountMax: amountMaxController.text,
      comment: commentController.text,
      food: foodController.text,
      selectedUnit: selectedUnit,
      selectedFood: selectedFood,
    );
  }

  IngredientDraft toModel() {
    return IngredientDraft(
        unitId: selectedUnit?.id,
        amountMin: amountMinController.text.isEmpty
            ? null
            : double.parse(amountMinController.text),
        amountMax: amountMaxController.text.isEmpty
            ? null
            : double.parse(amountMaxController.text),
        food: (selectedFood != null) ? selectedFood!.name : foodController.text,
        comment:
            commentController.text.isEmpty ? null : commentController.text);
  }

  void dispose() {
    amountMinController.dispose();
    amountMaxController.dispose();
    commentController.dispose();
    foodController.dispose();
  }
}

class _IngredientGroupWidget extends StatefulWidget {
  final IngredientGroupData group;
  final int index;
  final List<Unit> units;
  final List<Food> foods;
  final Map<String, dynamic> currentLangData;
  final Future<List<Unit>> Function(String) searchUnits;
  final Future<List<Food>> Function(String) searchFoods;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback? onRemove;
  final Function(int oldIndex, int newIndex) onReorderIngredients;

  const _IngredientGroupWidget({
    required this.group,
    required this.index,
    required this.units,
    required this.foods,
    required this.currentLangData,
    required this.searchUnits,
    required this.searchFoods,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    this.onRemove,
    required this.onReorderIngredients,
  });

  @override
  State<_IngredientGroupWidget> createState() => _IngredientGroupWidgetState();
}

class _IngredientGroupWidgetState extends State<_IngredientGroupWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drag_indicator, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: widget.group.nameController,
                    decoration: InputDecoration(
                      labelText: 'Group ${widget.index + 1} Title *',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 2) return 'Min 2 characters';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.canMoveUp)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    onPressed: widget.onMoveUp,
                    tooltip: 'Move group up',
                  ),
                if (widget.canMoveDown)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    onPressed: widget.onMoveDown,
                    tooltip: 'Move group down',
                  ),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.onRemove,
                    tooltip: 'Remove group',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.group.ingredients.length,
              onReorder: widget.onReorderIngredients,
              itemBuilder: (context, i) {
                return Padding(
                  key: ValueKey('ingredient_${widget.index}_$i'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _IngredientWidget(
                    ingredient: widget.group.ingredients[i],
                    units: widget.units,
                    foods: widget.foods,
                    currentLangData: widget.currentLangData,
                    searchUnits: widget.searchUnits,
                    searchFoods: widget.searchFoods,
                    canMoveUp: i > 0,
                    canMoveDown: i < widget.group.ingredients.length - 1,
                    onMoveUp: () {
                      setState(() {
                        final item = widget.group.ingredients.removeAt(i);
                        widget.group.ingredients.insert(i - 1, item);
                      });
                    },
                    onMoveDown: () {
                      setState(() {
                        final item = widget.group.ingredients.removeAt(i);
                        widget.group.ingredients.insert(i + 1, item);
                      });
                    },
                    onRemove: widget.group.ingredients.length > 1
                        ? () =>
                            setState(() => widget.group.ingredients.removeAt(i))
                        : null,
                  ),
                );
              },
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => widget.group.ingredients.add(Ingredient())),
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientWidget extends StatefulWidget {
  final Ingredient ingredient;
  final List<Unit> units;
  final List<Food> foods;
  final Future<List<Unit>> Function(String) searchUnits;
  final Future<List<Food>> Function(String) searchFoods;
  final Map<String, dynamic> currentLangData;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback? onRemove;

  const _IngredientWidget({
    required this.ingredient,
    required this.units,
    required this.foods,
    required this.searchUnits,
    required this.searchFoods,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.currentLangData,
    this.onRemove,
  });

  @override
  State<_IngredientWidget> createState() => _IngredientWidgetState();
}

class _IngredientWidgetState extends State<_IngredientWidget> {
  Unit? _currentUnitSelection;
  Food? _currentFoodSelection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              if (isWide)
                Row(
                  children: [
                    Expanded(flex: 2, child: _buildUnitDropdown()),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _buildFoodField()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildAmountMinField()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildAmountMaxField()),
                    if (widget.onRemove != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: widget.onRemove,
                      ),
                  ],
                )
              else ...[
                Row(
                  children: [
                    Expanded(child: _buildUnitDropdown()),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _buildFoodField()),
                    if (widget.onRemove != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: widget.onRemove,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildAmountMinField()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildAmountMaxField()),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              _buildCommentField(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnitDropdown() {
    var initValue = "";

    if (widget.ingredient.selectedUnit != null) {
      initValue = widget.currentLangData["units"]
          [widget.ingredient.selectedUnit!.name]["singular"];
    }

    return Autocomplete<Unit>(
      initialValue: TextEditingValue(text: initValue),
      optionsBuilder: (textEditingValue) async {
        return await widget.searchUnits(
            textEditingValue.text.isEmpty ? " " : textEditingValue.text);
      },
      displayStringForOption: (option) =>
          widget.currentLangData["units"][option.name]["singular"],
      onSelected: (selection) {
        setState(() => widget.ingredient.selectedUnit = selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (s) {
            setState(() => widget.ingredient.selectedUnit = null);
            _currentUnitSelection = null;
          },
          decoration: const InputDecoration(
            labelText: 'Unit *',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            // if (!widget.units.contains(v)) return 'Invalid unit';
            if (widget.ingredient.selectedUnit == null) {
              return 'Select Unit from List!';
            }
            return null;
          },
          onFieldSubmitted: (_) {
            if (_currentUnitSelection != null) {
              controller.text = widget.currentLangData["units"]
                  [_currentUnitSelection!.name]["singular"];
              widget.ingredient.selectedUnit = _currentUnitSelection!;
              _currentUnitSelection = null;
              // widget.onChanged();
            }
            onFieldSubmitted();
          },
        );
      },
    );
  }

  Widget _buildFoodField() {
    return Autocomplete<Food>(
      initialValue:
          TextEditingValue(text: widget.ingredient.foodController.text),
      optionsBuilder: (textEditingValue) async {
        return await widget.searchFoods(
            textEditingValue.text.isEmpty ? " " : textEditingValue.text);
      },
      displayStringForOption: (option) => option.name,
      onSelected: (selection) {
        widget.ingredient.foodController.text = selection.name;
        setState(() => widget.ingredient.selectedFood = selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        widget.ingredient.foodController.text = controller.text;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Food',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            return null;
          },
          onChanged: (v) {
            if (!widget.foods.contains(v)) {
              // TODO: broken
              widget.ingredient.selectedFood = null;
            }
          },
          onFieldSubmitted: (_) {
            if (_currentFoodSelection != null &&
                widget.foods.contains(_currentFoodSelection)) {
              controller.text = _currentFoodSelection!.name;
              widget.ingredient.foodController.text =
                  _currentFoodSelection!.name;
              widget.ingredient.selectedFood = _currentFoodSelection!;
              _currentFoodSelection = null;
              // widget.onChanged();
            }
            onFieldSubmitted();
          },
        );
      },
    );
  }

  Widget _buildAmountMinField() {
    return TextFormField(
      controller: widget.ingredient.amountMinController,
      decoration: const InputDecoration(
        labelText: 'Min',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      validator: (v) {
        if (v == null || v.isEmpty) {
          return null;
        }

        final val = double.tryParse(v!);

        if (val == null || val <= 0) return '>0';
        return null;
      },
    );
  }

  Widget _buildAmountMaxField() {
    return TextFormField(
      controller: widget.ingredient.amountMaxController,
      decoration: const InputDecoration(
        labelText: 'Max',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      validator: (v) {
        if (v != null && v.isNotEmpty) {
          final maxVal = double.tryParse(v);
          final minVal =
              double.tryParse(widget.ingredient.amountMinController.text);
          if (maxVal == null) return 'Invalid';
          if (minVal != null && maxVal <= minVal) return '>min';
        }
        return null;
      },
    );
  }

  Widget _buildCommentField() {
    return TextFormField(
      controller: widget.ingredient.commentController,
      decoration: const InputDecoration(
        labelText: 'Comment',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
