// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:p009/main.dart';

void main() {
  testWidgets('Snake game loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SnakeGameApp());

    // Verify that the Snake game elements are present.
    expect(find.text('SNAKE'), findsOneWidget); // Header title
    expect(find.text('SNAKE GAME'), findsOneWidget); // Overlay title
    expect(find.text('START GAME'), findsOneWidget);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('BEST'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2)); // Initial score and best score

    // Verify control buttons are present.
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
