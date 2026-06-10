import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import 'inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return InventoryService(supabase);
});

final inventoryListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final service = ref.watch(inventoryServiceProvider);
  final list = await service.fetchInventory();
  return list;
});
