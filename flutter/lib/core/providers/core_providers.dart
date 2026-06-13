import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';
import '../storage/token_storage.dart';

/// `main.dart` da `ProviderScope(overrides: [...])` orqali haqiqiy instance
/// bilan almashtiriladi (TokenStorage async init talab qiladi).
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  throw UnimplementedError('tokenStorageProvider main.dart da override qilinishi kerak');
});

/// 401 sodir bo'lganda token tozalanadi → router avtomatik login'ga yo'naltiradi.
/// Bayroq sifatida oddiy StateProvider — har 401 da inkrement.
final unauthorizedSignalProvider = StateProvider<int>((ref) => 0);

/// Butun ilova uchun yagona, tokenli Dio. Auth va chat shu instance'dan
/// foydalanadi — token interceptor barcha so'rovlarga qo'llanadi.
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return DioClient.create(
    storage: storage,
    onUnauthorized: () {
      ref.read(unauthorizedSignalProvider.notifier).state++;
    },
  );
});
