import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'backend/firebase_config.dart';
import 'backend/firebase_family_backend.dart';
import 'data/family_repository.dart';
import 'data/family_store.dart';
import 'services/app_services.dart';

Future<void> main() async {
  // Needed before using plugins (SharedPreferences, Firebase) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase only when configured (see backend/firebase_config.dart); otherwise offline demo mode.
  FirebaseFamilyBackend? backend;
  if (FirebaseConfig.enabled) {
    await FirebaseConfig.initialize();
    backend = FirebaseFamilyBackend.live();
  }

  final store = await FamilyStore.open(LocalFamilyRepository(), backend: backend);
  runApp(
    FamilyCallApp(
      store: store,
      services: AppServices.device(backend: backend),
    ),
  );
}
