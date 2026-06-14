import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/slides_repository.dart';

final slidesRepositoryProvider = Provider<SlidesRepository>((ref) {
  return SlidesRepository(ref.watch(dioProvider));
});

enum SlidesStatus { idle, loading, success, error }

class SlidesState {
  final SlidesStatus status;
  final SlideResult? result;
  final String? error;

  const SlidesState({
    this.status = SlidesStatus.idle,
    this.result,
    this.error,
  });

  bool get isLoading => status == SlidesStatus.loading;

  SlidesState copyWith({
    SlidesStatus? status,
    SlideResult? result,
    String? error,
  }) {
    return SlidesState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error,
    );
  }
}

class SlidesNotifier extends StateNotifier<SlidesState> {
  final SlidesRepository _repo;
  SlidesNotifier(this._repo) : super(const SlidesState());

  Future<void> generate(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || state.isLoading) return;

    state = const SlidesState(status: SlidesStatus.loading);
    final result = await _repo.generate(text);
    result.fold(
      (error) =>
          state = SlidesState(status: SlidesStatus.error, error: error),
      (slide) =>
          state = SlidesState(status: SlidesStatus.success, result: slide),
    );
  }

  void reset() => state = const SlidesState();
}

final slidesProvider =
    StateNotifierProvider<SlidesNotifier, SlidesState>((ref) {
  return SlidesNotifier(ref.watch(slidesRepositoryProvider));
});
