import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flashcard_ai/services/local_state_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('uses dark mode by default', () async {
    final store = await LocalStateStore.load();

    expect(store.themeMode, ThemeMode.dark);
  });

  test('persists the selected theme mode locally', () async {
    final store = await LocalStateStore.load();

    store.setThemeMode(ThemeMode.light);
    final reloaded = await LocalStateStore.load();

    expect(reloaded.themeMode, ThemeMode.light);
  });
}
