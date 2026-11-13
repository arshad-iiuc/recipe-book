import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/recipe.dart';

const recipeBoxName = 'recipes';
const deletedBoxName = 'deleted';

// Recipes made on this device get ids from here up. DummyJSON ids are 1 to 50.
const firstLocalId = 1000;

// Keeps every recipe the app downloads, so the list still works offline,
// and remembers which recipes the user deleted.
// ponytail: one JSON string per recipe keyed by id, and search matches the
// name only. Fine for about 50 items; upgrade path is a typed Hive adapter
// or a real database.
class RecipeCache {
  // Null when storage could not start; the app then runs without a cache.
  Box<String>? get _box =>
      Hive.isBoxOpen(recipeBoxName) ? Hive.box<String>(recipeBoxName) : null;

  Box<bool>? get _deleted =>
      Hive.isBoxOpen(deletedBoxName) ? Hive.box<bool>(deletedBoxName) : null;

  bool isDeleted(int id) => _deleted?.containsKey(id) ?? false;

  // ponytail: an edit is marked with the extra key 'edited:ID' in the same
  // box; upgrade path is a separate Hive box.
  bool isEdited(int id) => _box?.containsKey('edited:$id') ?? false;

  Future<void> saveEdit(Recipe recipe) async {
    try {
      await _box?.put(recipe.id, jsonEncode(recipe.toJson()));
      await _box?.put('edited:${recipe.id}', '1');
    } catch (_) {
      // A failed local write must never crash the screen.
    }
  }

  // The server sends the original recipe, so swap in the edited copy.
  Recipe withEdits(Recipe r) {
    if (!isEdited(r.id)) return r;
    try {
      return Recipe.fromJson(
        jsonDecode(_box!.get(r.id)!) as Map<String, dynamic>,
      );
    } catch (_) {
      return r;
    }
  }

  // Deleted ids count as used, so a new recipe never gets an old id back.
  int nextLocalId() {
    final used = [
      ...?_box?.keys.whereType<int>(),
      ...?_deleted?.keys.whereType<int>(),
    ];
    final top = used.fold<int>(firstLocalId - 1, (a, b) => b > a ? b : a);
    return top + 1;
  }

  // ponytail: if storage failed to start, the recipe is not kept after the
  // app closes; upgrade path is returning false and telling the user.
  Future<void> addLocal(Recipe recipe) async {
    try {
      await _box?.put(recipe.id, jsonEncode(recipe.toJson()));
    } catch (_) {
      // A failed local write must never crash the screen.
    }
  }

  // Recipes made on this device, newest first, filtered like search().
  List<Recipe> local({String query = '', String? mealType}) => search(
        query: query,
        mealType: mealType,
      ).where((r) => r.id >= firstLocalId).toList().reversed.toList();

  // The server forgets deletions, so the id is kept here and filtered out of
  // every download. ponytail: deleted ids are never forgotten, so there is no
  // "restore" yet.
  Future<void> delete(int id) async {
    try {
      await _deleted?.put(id, true);
      await _box?.delete(id);
    } catch (_) {
      // A failed local write must never crash the screen.
    }
  }

  Future<void> save(List<Recipe> recipes) async {
    final box = _box;
    if (box == null) return;
    try {
      await box.putAll({
        for (final r in recipes)
          if (!isDeleted(r.id) && !isEdited(r.id)) r.id: jsonEncode(r.toJson()),
      });
    } catch (_) {
      // A failed cache write must never break the screen.
    }
  }

  // Same rule as the service: a search query wins over the meal type.
  List<Recipe> search({String query = '', String? mealType}) {
    final box = _box;
    if (box == null) return [];
    final all = <Recipe>[];
    for (final json in box.values) {
      try {
        all.add(Recipe.fromJson(jsonDecode(json) as Map<String, dynamic>));
      } catch (_) {
        // Skip a damaged entry instead of losing the whole list.
      }
    }
    all.sort((a, b) => a.id.compareTo(b.id));

    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      return all.where((r) => r.name.toLowerCase().contains(q)).toList();
    }
    if (mealType != null) {
      final m = mealType.toLowerCase();
      return all
          .where((r) => r.mealType.any((t) => t.toLowerCase() == m))
          .toList();
    }
    return all;
  }
}
