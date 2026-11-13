import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/models/recipe.dart';

Map<String, dynamic> sample() => {
      'id': 1,
      'name': 'Classic Margherita Pizza',
      'ingredients': ['Pizza dough', 'Tomato sauce'],
      'instructions': ['Preheat the oven.', 'Bake and serve.'],
      'prepTimeMinutes': 20,
      'cookTimeMinutes': 15,
      'servings': 4,
      'difficulty': 'Easy',
      'cuisine': 'Italian',
      'caloriesPerServing': 300,
      'tags': ['Pizza', 'Italian'],
      'image': 'https://cdn.dummyjson.com/recipe-images/1.webp',
      'rating': 4.6,
      'reviewCount': 98,
      'mealType': ['Dinner'],
    };

void main() {
  test('fromJson reads fields and totalMinutes adds up', () {
    final r = Recipe.fromJson(sample());
    expect(r.name, 'Classic Margherita Pizza');
    expect(r.ingredients.length, 2);
    expect(r.totalMinutes, 35);
    expect(r.rating, 4.6);
  });

  test('a whole-number rating does not crash', () {
    final r = Recipe.fromJson({...sample(), 'rating': 5});
    expect(r.rating, 5.0);
  });
}
