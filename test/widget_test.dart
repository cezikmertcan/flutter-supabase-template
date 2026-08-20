import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter_template/main.dart';
import 'package:supabase_flutter_template/services/auth_service.dart';
import 'package:supabase_flutter_template/services/local_state_store.dart';
import 'package:supabase_flutter_template/services/remote_state_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows a usable local-first dashboard', (tester) async {
    final localState = await LocalStateStore.load();
    final auth = AuthService.unconfigured();
    final sync = RemoteStateSyncService(auth: auth, localState: localState);
    addTearDown(sync.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      SupabaseFlutterTemplateApp(
        auth: auth,
        localState: localState,
        sync: sync,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Starter dashboard'), findsOneWidget);
    expect(
      find.text('Supabase is not configured; the local demo remains usable.'),
      findsOneWidget,
    );
    expect(find.text('0 actions'), findsOneWidget);

    expect(find.text('Record local action'), findsOneWidget);
  });
}
