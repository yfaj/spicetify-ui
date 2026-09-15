import 'package:flutter_test/flutter_test.dart';
import 'package:spicetify_ui/main.dart' as app;

void main() {
  test('app entry point exists', () {
    expect(app.buildApp, isA<Function>());
  });
}
