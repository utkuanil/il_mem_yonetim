import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'json_repository.dart';

final jsonRepositoryProvider = Provider<JsonRepository>((ref) {
  return JsonRepository();
});

final jsonDataProvider = FutureProvider.family<dynamic, String>((ref, path) async {
  final repo = ref.read(jsonRepositoryProvider);
  return repo.getJson(path); // ✅ Map veya List dönebilir
});
