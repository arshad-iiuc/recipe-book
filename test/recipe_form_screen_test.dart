import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/models/recipe.dart';
import 'package:recipe_book/screens/recipe_form_screen.dart';

void main() {
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('empty form shows errors and stays open', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(const MaterialApp(home: RecipeFormScreen()));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Required'), findsWidgets);
    expect(find.text('Add recipe'), findsOneWidget);
  });

  testWidgets('valid form returns a Recipe', (tester) async {
    tallScreen(tester);
    Recipe? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.push<Recipe>(
              context,
              MaterialPageRoute(builder: (_) => const RecipeFormScreen()),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name')), 'Soup');
    await tester.enterText(find.byKey(const Key('cuisine')), 'Thai');
    await tester.enterText(find.byKey(const Key('prep')), '5');
    await tester.enterText(find.byKey(const Key('cook')), '10');
    await tester.enterText(find.byKey(const Key('servings')), '2');
    await tester.enterText(find.byKey(const Key('calories')), '200');
    await tester.enterText(find.byKey(const Key('ingredients')), 'water\nsalt');
    await tester.enterText(find.byKey(const Key('instructions')), 'Boil it');
    await tester.tap(find.widgetWithText(FilterChip, 'Lunch'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Soup');
    expect(result?.ingredients, ['water', 'salt']);
    expect(result?.mealType, ['Lunch']);
    expect(result?.servings, 2);
  });
}
