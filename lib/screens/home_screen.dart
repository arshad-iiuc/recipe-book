import 'dart:async';

import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_cache.dart';
import '../services/recipe_service.dart';
import '../widgets/recipe_card.dart';
import 'detail_screen.dart';
import 'recipe_form_screen.dart';

// ponytail: meal types are hard-coded; upgrade path is reading them from the API.
const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.service, this.cache});

  // Tests pass fakes; the app uses the defaults.
  final RecipeService? service;
  final RecipeCache? cache;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecipeService _service = widget.service ?? RecipeService();
  late final RecipeCache _cache = widget.cache ?? RecipeCache();
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Recipe> _recipes = [];
  int _fetched = 0; // items taken from the server, including hidden deleted ones
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _offline = false; // true while showing saved recipes
  String? _error;
  String _query = '';
  String? _mealType;
  int _gen = 0; // answers to older requests are ignored

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // The server still returns recipes the user deleted, so hide them here.
  List<Recipe> _visible(List<Recipe> list) =>
      list.where((r) => !_cache.isDeleted(r.id)).map(_cache.withEdits).toList();

  // If the screen is too tall to scroll, nothing would ever trigger the
  // next page, so load it right away.
  void _fillIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scroll.hasClients &&
          _scroll.position.maxScrollExtent <= 0) {
        _loadMore();
      }
    });
  }

  Future<void> _reload({bool clear = false}) async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      if (clear) {
        _recipes = [];
        _fetched = 0;
        _total = 0;
        _offline = false;
      }
    });
    try {
      final page = await _service.fetch(query: _query, mealType: _mealType);
      _cache.save(page.recipes); // never throws, see RecipeCache.save
      if (!mounted || gen != _gen) return;
      setState(() {
        // Recipes made on this device go first, then the server page.
        _recipes = [
          ..._cache.local(query: _query, mealType: _mealType),
          ..._visible(page.recipes),
        ];
        _fetched = page.recipes.length;
        _total = page.total;
        _offline = false;
        _loading = false;
      });
      _fillIfShort();
    } on ApiException catch (e) {
      if (!mounted || gen != _gen) return;
      if (_recipes.isNotEmpty) {
        // A failed refresh keeps the list on screen and only shows a message.
        setState(() => _loading = false);
        _snack(e.message);
        return;
      }
      final saved = _cache.search(query: _query, mealType: _mealType);
      setState(() {
        _loading = false;
        if (saved.isEmpty) {
          _error = e.message;
        } else {
          _recipes = saved;
          _fetched = saved.length;
          _total = saved.length; // nothing more to page through offline
          _offline = true;
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _fetched >= _total) return;
    final gen = _gen;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.fetch(
        skip: _fetched,
        query: _query,
        mealType: _mealType,
      );
      _cache.save(page.recipes);
      if (!mounted || gen != _gen) return;
      setState(() {
        _recipes = [..._recipes, ..._visible(page.recipes)];
        _fetched += page.recipes.length;
        // An empty page means the server has nothing more, whatever it says.
        _total = page.recipes.isEmpty ? _fetched : page.total;
        _loadingMore = false;
      });
      _fillIfShort();
    } on ApiException catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _loadingMore = false);
      _snack(e.message);
    }
  }

  Future<void> _open(Recipe recipe) async {
    final deleted = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: recipe,
          service: _service,
          cache: _cache,
        ),
      ),
    );
    if (deleted is Recipe && mounted) {
      // Edited: swap the new copy into the list.
      setState(() {
        _recipes = [
          for (final r in _recipes) r.id == deleted.id ? deleted : r,
        ];
      });
      return;
    }
    if (deleted == true && mounted) {
      setState(() {
        _recipes = _recipes.where((r) => r.id != recipe.id).toList();
      });
    }
  }

  Future<void> _add() async {
    final draft = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(builder: (_) => const RecipeFormScreen()),
    );
    if (draft == null || !mounted) return;
    // The form returns id 0; the real id is chosen here.
    final recipe = Recipe.fromJson({...draft.toJson(), 'id': _cache.nextLocalId()});
    try {
      await _service.addRecipe(recipe); // real POST first
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
      return;
    }
    await _cache.addLocal(recipe); // the server forgets it, so keep our copy
    if (!mounted) return;
    _snack('Recipe added.');
    _selectMeal(null); // clears search and chip, reloads, new recipe is first
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    setState(() {}); // refreshes the clear button
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = text.trim();
      if (q == _query) return;
      _query = q;
      if (q.isNotEmpty) _mealType = null;
      _reload(clear: true);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    _query = '';
    _reload(clear: true);
  }

  void _selectMeal(String? meal) {
    _debounce?.cancel();
    _searchCtrl.clear();
    _query = '';
    _mealType = meal;
    _reload(clear: true);
  }

  Widget _offlineBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline: showing saved recipes. Pull down to retry.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(IconData icon, String text, {bool retry = false}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 64),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
        if (retry) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => _reload(clear: true),
              child: const Text('Retry'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _body() {
    if (_loading && _recipes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return _message(Icons.wifi_off, _error!, retry: true);
    if (_recipes.isEmpty) return _message(Icons.search_off, 'No recipes found.');
    return GridView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 300,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _recipes.length,
      itemBuilder: (context, i) => RecipeCard(
        recipe: _recipes[i],
        onTap: () => _open(_recipes[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Book')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Add recipe',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search recipes',
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final m in [null, ..._mealTypes])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: ChoiceChip(
                        label: Text(m ?? 'All'),
                        selected: _mealType == m,
                        onSelected: (_) => _selectMeal(m),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_offline) _offlineBanner(context),
          Expanded(
            child: RefreshIndicator(onRefresh: _reload, child: _body()),
          ),
          if (_loadingMore) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
