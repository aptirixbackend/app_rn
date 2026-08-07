import 'package:flutter_test/flutter_test.dart';

import 'package:real_estate_app/core/theme/app_theme.dart';

void main() {
  test('AppTheme.light builds a Material 3 theme', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
  });
}
