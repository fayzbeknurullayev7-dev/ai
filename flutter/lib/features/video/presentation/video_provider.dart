import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/video_repository.dart';

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepository(ref.watch(dioProvider));
});

enum VideoStatus { idle, loading, keyRequired, success, error }

class VideoState {
  final VideoStatus status;
  final String? message;
  final String? videoUrl;

  const VideoState({
    this.status = VideoStatus.idle,
    this.message,
    this.videoUrl,
  });

  bool get isLoading => status == VideoStatus.loading;

  VideoState copyWith({
    VideoStatus? status,
    String? message,
    String? videoUrl,
  }) {
    return VideoState(
      status: status ?? this.status,
      message: message ?? this.message,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }
}

class VideoNotifier extends StateNotifier<VideoState> {
  final VideoRepository _repo;
  VideoNotifier(this._repo) : super(const VideoState());

  Future<void> generate(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || state.isLoading) return;

    state = const VideoState(status: VideoStatus.loading);
    final outcome = await _repo.generate(text);

    if (outcome.videoUrl != null && outcome.videoUrl!.isNotEmpty) {
      state = VideoState(
        status: VideoStatus.success,
        videoUrl: outcome.videoUrl,
        message: outcome.message,
      );
    } else if (outcome.keyRequired) {
      state = VideoState(
        status: VideoStatus.keyRequired,
        message: outcome.message,
      );
    } else {
      state = VideoState(status: VideoStatus.error, message: outcome.message);
    }
  }

  void reset() => state = const VideoState();
}

final videoProvider =
    StateNotifierProvider<VideoNotifier, VideoState>((ref) {
  return VideoNotifier(ref.watch(videoRepositoryProvider));
});
