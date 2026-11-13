import 'package:flutter/material.dart';

import '../models/recipe.dart';

// ponytail: fixed lists; upgrade path is reading them from the API.
const _difficulties = ['Easy', 'Medium', 'Hard'];
const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert'];

/// Add form (initial == null) or Edit form (initial != null).
/// Pops a [Recipe] on Save, or null if the user goes back.
class RecipeFormScreen extends StatefulWidget {
  const RecipeFormScreen({super.key, this.initial});

  final Recipe? initial;

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Recipe? _r = widget.initial;

  late final _name = TextEditingController(text: _r?.name ?? '');
  late final _cuisine = TextEditingController(text: _r?.cuisine ?? '');
  late final _prep = TextEditingController(text: _r?.prepTimeMinutes.toString() ?? '');
  late final _cook = TextEditingController(text: _r?.cookTimeMinutes.toString() ?? '');
  late final _servings = TextEditingController(text: _r?.servings.toString() ?? '');
  late final _calories = TextEditingController(text: _r?.caloriesPerServing.toString() ?? '');
  late final _ingredients = TextEditingController(text: _r?.ingredients.join('\n') ?? '');
  late final _instructions = TextEditingController(text: _r?.instructions.join('\n') ?? '');
  late final _tags = TextEditingController(text: _r?.tags.join(', ') ?? '');
  late final _image = TextEditingController(text: _r?.image ?? '');

  late String _difficulty =
      _difficulties.contains(_r?.difficulty) ? _r!.difficulty : 'Easy';
  late final Set<String> _meals = {...?_r?.mealType};

  @override
  void dispose() {
    for (final c in [
      _name, _cuisine, _prep, _cook, _servings, _calories,
      _ingredients, _instructions, _tags, _image,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // One item per line; blank lines are dropped.
  List<String> _lines(String text) =>
      text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? Function(String?) _number({int min = 0}) => (v) {
        final n = int.tryParse((v ?? '').trim());
        if (n == null) return 'Enter a whole number';
        if (n < min) return 'Must be at least $min';
        return null;
      };

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one meal type.')),
      );
      return;
    }
    // Building through fromJson means the form cannot disagree with the model.
    // id 0 is a placeholder: the caller (Step 12b) assigns the real id.
    // ponytail: empty image stays '' until we check how the card shows it.
    Navigator.pop(
      context,
      Recipe.fromJson({
        'id': _r?.id ?? 0,
        'name': _name.text.trim(),
        'ingredients': _lines(_ingredients.text),
        'instructions': _lines(_instructions.text),
        'prepTimeMinutes': int.parse(_prep.text.trim()),
        'cookTimeMinutes': int.parse(_cook.text.trim()),
        'servings': int.parse(_servings.text.trim()),
        'difficulty': _difficulty,
        'cuisine': _cuisine.text.trim(),
        'caloriesPerServing': int.parse(_calories.text.trim()),
        'tags': _tags.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'image': _image.text.trim(),
        'rating': _r?.rating ?? 0.0,
        'reviewCount': _r?.reviewCount ?? 0,
        'mealType': _meals.toList(),
      }),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    Key? key,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int maxLines = 1,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: key,
        controller: c,
        validator: validator,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_r == null ? 'Add recipe' : 'Edit recipe'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field('Name', _name, key: const Key('name'), validator: _required),
                  _field('Cuisine', _cuisine, key: const Key('cuisine'), validator: _required),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final d in _difficulties)
                          DropdownMenuItem(value: d, child: Text(d)),
                      ],
                      onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
                    ),
                  ),
                  const Text('Meal type'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in _mealTypes)
                        FilterChip(
                          label: Text(m),
                          selected: _meals.contains(m),
                          onSelected: (on) => setState(
                            () => on ? _meals.add(m) : _meals.remove(m),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field('Prep time (minutes)', _prep,
                      key: const Key('prep'), validator: _number(), keyboard: TextInputType.number),
                  _field('Cook time (minutes)', _cook,
                      key: const Key('cook'), validator: _number(), keyboard: TextInputType.number),
                  _field('Servings', _servings,
                      key: const Key('servings'), validator: _number(min: 1), keyboard: TextInputType.number),
                  _field('Calories per serving', _calories,
                      key: const Key('calories'), validator: _number(), keyboard: TextInputType.number),
                  _field('Ingredients', _ingredients,
                      key: const Key('ingredients'),
                      validator: (v) => _lines(v ?? '').isEmpty ? 'Add at least one ingredient' : null,
                      keyboard: TextInputType.multiline,
                      maxLines: 5,
                      helper: 'One ingredient per line'),
                  _field('Instructions', _instructions,
                      key: const Key('instructions'),
                      validator: (v) => _lines(v ?? '').isEmpty ? 'Add at least one step' : null,
                      keyboard: TextInputType.multiline,
                      maxLines: 5,
                      helper: 'One step per line'),
                  _field('Tags', _tags, helper: 'Separate with commas (optional)'),
                  _field('Image URL', _image, keyboard: TextInputType.url, helper: 'Optional'),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
