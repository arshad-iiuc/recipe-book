import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/models/recipe.dart';
import 'package:recipe_book/screens/detail_screen.dart';
import 'package:recipe_book/services/recipe_cache.dart';
import 'package:recipe_book/services/recipe_service.dart';
import 'package:recipe_book/widgets/recipe_card.dart';

import 'recipe_test.dart' show sample;

class FakeService extends RecipeService {
  FakeService({this.fail = false});

  final bool fail;
  final deleted = <int>[];

  @override
  Future<void> deleteRecipe(int id) async {
    if (fail) throw const ApiException('No internet connection.');
    deleted.add(id);
  }
}

class FakeCache extends RecipeCache {
  final deleted = <int>[];

  @override
  Future<void> delete(int id) async => deleted.add(id);
}

final recipe = Recipe.fromJson(sample());
bool? popped; // what the detail page returned when it closed

Future<void> openDetail(
  WidgetTester tester,
  FakeService service,
  FakeCache cache,
) async {
  popped = null;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popped = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                      recipe: recipe,
                      service: service,
                      cache: cache,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detail shows info, ingredients and numbered steps',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: recipe,
          service: FakeService(),
          cache: FakeCache(),
        ),
      ),
    );
    expect(find.text('Classic Margherita Pizza'), findsOneWidget);
    expect(find.text('35 min'), findsOneWidget);
    expect(find.text('Pizza dough'), findsOneWidget);
    expect(find.text('Preheat the oven.'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // the number of step 2
  });

  testWidgets('tapping a card calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: RecipeCard(recipe: recipe, onTap: () => taps++),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Classic Margherita Pizza'));
    expect(taps, 1);
  });

  testWidgets('delete asks first, then calls the API and the cache, then closes',
      (tester) async {
    final service = FakeService();
    final cache = FakeCache();
    await openDetail(tester, service, cache);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete recipe?'), findsOneWidget);
    expect(service.deleted, isEmpty); // nothing happens before confirming

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(service.deleted, [1]);
    expect(cache.deleted, [1]);
    expect(popped, isTrue);
  });

  testWidgets('cancel deletes nothing', (tester) async {
    final service = FakeService();
    final cache = FakeCache();
    await openDetail(tester, service, cache);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.deleted, isEmpty);
    expect(cache.deleted, isEmpty);
    expect(find.text('Ingredients'), findsOneWidget); // still on the page
    expect(popped, isNull);
  });

  testWidgets('API failure keeps the recipe and shows the message',
      (tester) async {
    final service = FakeService(fail: true);
    final cache = FakeCache();
    await openDetail(tester, service, cache);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No internet connection.'), findsOneWidget);
    expect(cache.deleted, isEmpty); // not hidden locally
    expect(find.text('Ingredients'), findsOneWidget);
    expect(popped, isNull);
  });
}
