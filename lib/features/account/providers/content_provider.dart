import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/providers/orders_providers.dart';
import '../../../shared/models/app_models.dart';

final appContentProvider = FutureProvider.autoDispose.family<AppContent, String>((ref, slug) async {
  return ref.read(accountRepositoryProvider).fetchAppContent(slug);
});
