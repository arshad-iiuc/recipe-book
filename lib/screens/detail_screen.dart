import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_cache.dart';
import '../services/recipe_service.dart';
import 'recipe_form_screen.dart';

Widget _info(IconData icon, String label) =>
    Chip(avatar: Icon(icon, size: 18), label: Text(label));

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.service,
    required this.cache,
  });

  final Recipe recipe;
  final RecipeService service;
  final RecipeCache cache;

  // Open the form pre-filled, save on the server first, then on the device,
  // then close this page with the edited recipe so the list can swap it in.
  Future<void> _edit(BuildContext context) async {
    final draft = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(builder: (_) => RecipeFormScreen(initial: recipe)),
    );
    if (draft == null || !context.mounted) return;
    try {
      await service.updateRecipe(draft);
      await cache.saveEdit(draft);
      if (context.mounted) Navigator.pop(context, draft);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  // Ask first, then delete on the server, then remember it locally, then
  // close this page with `true` so the list can drop the recipe.
  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('"${recipe.name}" will be removed from your list.'),
        actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Edit recipe',
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: () => _edit(context),
                  ),
                ),
              ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await service.deleteRecipe(recipe.id);
      await cache.delete(recipe.id);
      if (context.mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            // Round dark buttons so the icons are visible on any photo.
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Edit recipe',
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: () => _edit(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete recipe',
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: () => _delete(context),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'recipe-${recipe.id}',
                child: Image.network(
                  recipe.image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const ColoredBox(
                    color: Colors.black12,
                    child: Center(child: Icon(Icons.restaurant, size: 64)),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.name, style: text.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        '${recipe.cuisine} | ${recipe.mealType.join(', ')}',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _info(Icons.star,
                              '${recipe.rating} (${recipe.reviewCount})'),
                          _info(Icons.timer_outlined,
                              '${recipe.totalMinutes} min'),
                          _info(Icons.restaurant_menu,
                              '${recipe.servings} servings'),
                          _info(Icons.local_fire_department_outlined,
                              '${recipe.caloriesPerServing} kcal'),
                          _info(Icons.speed, recipe.difficulty),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Prep ${recipe.prepTimeMinutes} min, '
                        'cook ${recipe.cookTimeMinutes} min',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      Text('Ingredients', style: text.titleLarge),
                      const SizedBox(height: 8),
                      for (final item in recipe.ingredients)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 18, color: primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text('Instructions', style: text.titleLarge),
                      const SizedBox(height: 8),
                      for (var i = 0; i < recipe.instructions.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                child: Text('${i + 1}',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(recipe.instructions[i])),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in recipe.tags)
                            Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
