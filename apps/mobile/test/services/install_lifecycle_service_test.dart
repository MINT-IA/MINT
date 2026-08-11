import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/install_lifecycle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('central owned purge deletes the Mint Next 3a task key', () async {
    FlutterSecureStorage.setMockInitialValues({
      'mint_next_3a_task_v1': 'task',
      'unowned_key': 'keep',
    });

    expect(
      await InstallLifecycleService.purgeMintSecureStorage(
        includeAuthSession: false,
      ),
      isTrue,
    );

    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'mint_next_3a_task_v1'), isNull);
    expect(await storage.read(key: 'unowned_key'), 'keep');
  });
}
