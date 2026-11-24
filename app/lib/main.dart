import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'data/family_repository.dart';
import 'data/family_store.dart';

Future<void> main() async {
  // Needed before using plugins (SharedPreferences) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  final store = await FamilyStore.open(LocalFamilyRepository());
  runApp(FamilyCallApp(store: store));
}
