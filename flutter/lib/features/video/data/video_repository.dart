import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

/// Video generatsiya natijasi (Kling AI).
///
/// Hozircha backend'da Kling API key sozlanmagan → har doim [keyRequired]
/// holati qaytadi. Key qo'shilgach [videoUrl] to'ladi.
class VideoOutcome {
  final bool keyRequired;
  final String message;
  final String? videoUrl;

  const VideoOutcome({
    required this.keyRequired,
    required this.message,
    this.videoUrl,
  });
}

class VideoRepository {
  final Dio _dio;
  const VideoRepository(this._dio);

  Future<VideoOutcome> generate(String prompt) async {
    try {
      final response = await _dio.post(
        ApiConstants.videoGenerateEndpoint,
        data: {'prompt': prompt},
      );
      final data = response.data as Map<String, dynamic>;
      return VideoOutcome(
        keyRequired: data['status'] == 'key_required',
        message: data['detail'] as String? ?? 'Tayyor',
        videoUrl: data['video_url'] as String?,
      );
    } on DioException catch (e) {
      // 503 → Kling API key sozlanmagan (kutilgan holat).
      if (e.response?.statusCode == 503) {
        return VideoOutcome(
          keyRequired: true,
          message: _detail(e) ?? 'Kling API key kerak',
        );
      }
      return VideoOutcome(
        keyRequired: false,
        message: _detail(e) ?? e.message ?? 'Tarmoq xatosi',
      );
    } catch (e) {
      return VideoOutcome(keyRequired: false, message: e.toString());
    }
  }

  String? _detail(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return null;
  }
}
