import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class DioClient {
  /// [storage] berilsa — har so'rovga `Authorization: Bearer <token>`
  /// sarlavhasi avtomatik qo'shiladi (token mavjud bo'lsa). 401 qaytsa
  /// [onUnauthorized] chaqiriladi (token tozalab login'ga qaytarish uchun).
  static Dio create({
    TokenStorage? storage,
    void Function()? onUnauthorized,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (storage != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final token = storage.token;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
          onError: (e, handler) {
            if (e.response?.statusCode == 401) {
              onUnauthorized?.call();
            }
            handler.next(e);
          },
        ),
      );
    }

    // FIX (#3): `debugPrint` foundation paketidan keladi — import qo'shildi,
    // aks holda kompilyatsiya xatosi bo'lardi. Logni faqat debug rejimda yoqamiz.
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
    return dio;
  }
}
