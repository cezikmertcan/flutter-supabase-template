import 'package:flutter_test/flutter_test.dart';

import 'package:flashcard_ai/core/app_config.dart';

void main() {
  test('does not claim to be configured without dart defines', () {
    expect(AppConfig.supabaseUrl, isEmpty);
    expect(AppConfig.supabasePublishableKey, isEmpty);
    expect(AppConfig.isConfigured, isFalse);
  });
}
