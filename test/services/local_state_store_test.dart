import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter_template/services/local_state_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists the sample state payload', () async {
    final store = await LocalStateStore.load();

    store.recordAction();

    expect(store.actionCount, 1);
    expect(store.toPayload()['version'], 1);
    expect(store.toPayload()['actionCount'], 1);
    expect(store.lastActionAt, isNotNull);
  });

  test('can apply a remote payload', () async {
    final store = await LocalStateStore.load();

    store.mergeRemote(<String, dynamic>{
      'version': 1,
      'actionCount': 7,
      'lastActionAt': '2026-08-19T12:00:00.000Z',
    });

    expect(store.actionCount, 7);
    expect(store.lastActionAt, '2026-08-19T12:00:00.000Z');
  });
}
