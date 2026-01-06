import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zest/recipes/models/models.dart';
import 'package:zest/recipes/static_data_repository.dart';

class RecipeEditScreen extends ConsumerStatefulWidget {
  static String get routeNameEdit => 'recipe_edit';
  static String get routeNameDraftEdit => 'recipe_draft_edit';
  static String get routeNameCreate => 'recipe_create';

  final int? recipeId;

  // final List<String> availableLanguages;
  // final Map<int, String> validCategories;
  // final List<String> units;
  // final List<String> foods;
  // final Future<List<String>> Function(String query) searchUnits;
  // final Future<List<String>> Function(String query) searchFoods;
  // final Future<void> Function(Map<String, dynamic> formData) handleForm;

  const RecipeEditScreen({super.key, this.recipeId
      // required this.availableLanguages,
      // required this.validCategories,
      // required this.units,
      // required this.foods,
      // required this.searchUnits,
      // required this.searchFoods,
      // required this.handleForm,
      });

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _commentController = TextEditingController();
  final _sourceNameController = TextEditingController();
  final _sourcePageController = TextEditingController();
  final _sourceUrlController = TextEditingController();

  String? _selectedLanguage;
  bool _isPrivate = false;
  int _difficulty = 3;
  int _servings = 4;
  int _prepTimeHours = 0;
  int _prepTimeMinutes = 0;
  int _cookTimeHours = 0;
  int _cookTimeMinutes = 0;
  Set<int> _selectedCategories = {};
  List<InstructionGroup> _instructionGroups = [InstructionGroup()];
  List<IngredientGroup> _ingredientGroups = [IngredientGroup()];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _commentController.dispose();
    _sourceNameController.dispose();
    _sourcePageController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix validation errors')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final formData = {
        'title': _titleController.text,
        'subtitle':
            _subtitleController.text.isEmpty ? null : _subtitleController.text,
        'comment':
            _commentController.text.isEmpty ? null : _commentController.text,
        'language': _selectedLanguage,
        'isPrivate': _isPrivate,
        'difficulty': _difficulty,
        'servings': _servings,
        'prep_time': _prepTimeHours * 60 + _prepTimeMinutes,
        'cook_time': _cookTimeHours * 60 + _cookTimeMinutes,
        'sourceName': _sourceNameController.text.isEmpty
            ? null
            : _sourceNameController.text,
        'sourcePage': _sourcePageController.text.isEmpty
            ? null
            : _sourcePageController.text,
        'sourceUrl': _sourceUrlController.text.isEmpty
            ? null
            : _sourceUrlController.text,
        'categories': _selectedCategories.toList(),
        'instructionGroups': _instructionGroups.map((g) => g.toJson()).toList(),
        'ingredientGroups': _ingredientGroups.map((g) => g.toJson()).toList(),
      };

      // TODO: handle the form by uploading via repository.
      // await widget.handleForm(formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staticData = ref.watch(recipeStaticDataProvider);

    return staticData.when(
      loading: () {
        debugPrint("Loading...");
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
        debugPrint("layout./....");

        return LayoutBuilder(
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
                        _buildInstructionGroupsSection(),
                        const SizedBox(height: 32),
                        _buildIngredientGroupsSection(
                            data.units, data.foods, data.currentLanguageData),
                        const SizedBox(height: 48),
                        _buildSubmitButton(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
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
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subtitleController,
              decoration: const InputDecoration(
                labelText: 'Subtitle',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
            _buildDifficultySelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedLanguage,
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
      onChanged: (v) => setState(() => _selectedLanguage = v),
      validator: (v) => v == null ? 'Language is required' : null,
    );
  }

  Widget _buildServingsField() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: _servings.toString(),
            decoration: const InputDecoration(
              labelText: 'Servings *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final val = int.tryParse(v);
              if (val == null || val < 1 || val > 99) return '1-99';
              return null;
            },
            onChanged: (v) {
              final val = int.tryParse(v);
              if (val != null) _servings = val;
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => setState(() {
            if (_servings > 1) _servings--;
          }),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => setState(() {
            if (_servings < 99) _servings++;
          }),
        ),
      ],
    );
  }

  Widget _buildPrivateCheckbox() {
    return CheckboxListTile(
      title: const Text('Private Recipe'),
      subtitle: const Text('Only visible to you'),
      value: _isPrivate,
      onChanged: (v) => setState(() => _isPrivate = v ?? false),
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
              onTap: () => setState(() => _difficulty = level),
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
                    if (isPrep)
                      _prepTimeHours = val;
                    else
                      _cookTimeHours = val;
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
                    if (isPrep)
                      _prepTimeMinutes = val;
                    else
                      _cookTimeMinutes = val;
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
                decoration: const InputDecoration(
                  labelText: 'Source Page',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sourceUrlController,
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
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: () => setState(
                      () => _instructionGroups.add(InstructionGroup())),
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
                        ? () => setState(() => _instructionGroups.removeAt(i))
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
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: () =>
                      setState(() => _ingredientGroups.add(IngredientGroup())),
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
                        ? () => setState(() => _ingredientGroups.removeAt(i))
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
          : const Text('Save Recipe', style: TextStyle(fontSize: 18)),
    );
  }
}

class InstructionGroup {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController textController = TextEditingController();

  Map<String, dynamic> toJson() {
    return {
      'name': nameController.text,
      'text': textController.text,
    };
  }

  void dispose() {
    nameController.dispose();
    textController.dispose();
  }
}

class _InstructionGroupWidget extends StatelessWidget {
  final InstructionGroup group;
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

class IngredientGroup {
  final TextEditingController nameController = TextEditingController();
  final List<Ingredient> ingredients = [Ingredient()];

  Map<String, dynamic> toJson() {
    return {
      'name': nameController.text,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'unit': selectedUnit?.toJson(),
      'food': selectedFood?.toJson() ?? foodController.text,
      'amountMin': double.tryParse(amountMinController.text),
      'amountMax': amountMaxController.text.isEmpty
          ? null
          : double.tryParse(amountMaxController.text),
      'comment': commentController.text.isEmpty ? null : commentController.text,
    };
  }

  void dispose() {
    amountMinController.dispose();
    amountMaxController.dispose();
    commentController.dispose();
    foodController.dispose();
  }
}

class _IngredientGroupWidget extends StatefulWidget {
  final IngredientGroup group;
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
        // if (textEditingValue.text.isEmpty) {
        //   return widget.units.map((e) => e.name);
        // }
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
          },
          decoration: const InputDecoration(
            labelText: 'Unit *',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            // if (!widget.units.contains(v)) return 'Invalid unit';
            if (widget.ingredient.selectedUnit == null)
              return 'Select Unit from List!';
            return null;
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
        // if (textEditingValue.text.isEmpty) {
        //   return widget.foods.map((e) => e.name);
        // }
        // return await widget.searchFoods(textEditingValue.text);
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
              widget.ingredient.selectedFood = null;
            }
          },
        );
      },
    );
  }

  Widget _buildAmountMinField() {
    return TextFormField(
      controller: widget.ingredient.amountMinController,
      decoration: const InputDecoration(
        labelText: 'Min *',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        final val = double.tryParse(v);
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
