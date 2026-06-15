import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

/// Backend yaratgan slayd natijasi (UI uchun).
class SlideResult {
  final String title;
  final int slideCount;

  /// To'liq yuklab olish havolasi (`origin` + nisbiy `download_url`).
  final String downloadUrl;

  const SlideResult({
    required this.title,
    required this.slideCount,
    required this.downloadUrl,
  });
}

/// `/slides/generate` ni chaqiradi va to'liq yuklab olish havolasini quradi.
class SlidesRepository {
  final Dio _dio;
  const SlidesRepository(this._dio);

  Future<Either<String, SlideResult>> generate(String prompt) async {
    try {
      final response = await _dio.post(
        ApiConstants.slidesGenerateEndpoint,
        data: {'prompt': prompt},
      );
      final data = response.data as Map<String, dynamic>;
      final relative = data['download_url'] as String? ?? '';
      return Right(
        SlideResult(
          title: data['title'] as String? ?? 'Taqdimot',
          slideCount: (data['slide_count'] as num?)?.toInt() ?? 0,
          downloadUrl: '${ApiConstants.baseUrl.replaceAll("/api/v1", "")}$relative',
        ),
      );
    } on DioException catch (e) {
      return Left(_dioError(e));
    } catch (e) {
      return Left(e.toString());
    }
  }

  String _dioError(DioException e) {
    final detail = e.response?.data;
    if (detail is Map && detail['detail'] != null) {
      return detail['detail'].toString();
    }
    return e.message ?? 'Tarmoq xatosi';
  }
}
