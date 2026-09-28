import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/incidents_repository.dart';
import '../domain/incident.dart';

enum UploadStatus { waiting, uploading, done, failed }

@immutable
class PhotoUpload {
  const PhotoUpload({
    required this.localId,
    required this.path,
    this.legende,
    this.status = UploadStatus.waiting,
    this.progress = 0,
    this.error,
  });

  final String localId;
  final String path;
  final String? legende;
  final UploadStatus status;

  /// 0 → 1 pendant l'envoi.
  final double progress;
  final AppException? error;

  PhotoUpload copyWith({
    UploadStatus? status,
    double? progress,
    AppException? error,
  }) => PhotoUpload(
    localId: localId,
    path: path,
    legende: legende,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    error: error,
  );
}

/// File d'envoi des photos d'un incident : séquentielle, avec
/// progression et « Réessayer ». Survit à la navigation.
final photoUploadProvider =
    NotifierProvider.family<PhotoUploadController, List<PhotoUpload>, int>(
      PhotoUploadController.new,
    );

class PhotoUploadController extends Notifier<List<PhotoUpload>> {
  PhotoUploadController(this.idIncident);

  final int idIncident;
  bool _running = false;
  int _sequence = 0;

  @override
  List<PhotoUpload> build() => const [];

  bool get isBusy => state.any(
    (u) => u.status == UploadStatus.waiting || u.status == UploadStatus.uploading,
  );

  void enqueue(List<({String path, String? legende})> photos) {
    if (photos.isEmpty) return;
    state = [
      ...state,
      for (final photo in photos)
        PhotoUpload(
          localId: '$idIncident-${_sequence++}',
          path: photo.path,
          legende: photo.legende,
        ),
    ];
    unawaited(_pump());
  }

  void retry(String localId) {
    _update(
      localId,
      (u) => u.copyWith(status: UploadStatus.waiting, progress: 0),
    );
    unawaited(_pump());
  }

  void remove(String localId) => state = [
    for (final u in state)
      if (u.localId != localId || u.status == UploadStatus.uploading) u,
  ];

  void clearDone() => state = [
    for (final u in state)
      if (u.status != UploadStatus.done) u,
  ];

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (ref.mounted) {
        final next = state
            .where((u) => u.status == UploadStatus.waiting)
            .firstOrNull;
        if (next == null) break;
        await _upload(next);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _upload(PhotoUpload upload) async {
    _update(
      upload.localId,
      (u) => u.copyWith(status: UploadStatus.uploading, progress: 0),
    );
    var lastReported = 0.0;
    try {
      await ref
          .read(incidentsRepositoryProvider)
          .ajouterPhoto(
            idIncident,
            path: upload.path,
            legende: upload.legende,
            onProgress: (sent, total) {
              if (total <= 0) return;
              final progress = sent / total;
              if (progress - lastReported < 0.05 && progress < 1) return;
              lastReported = progress;
              _update(upload.localId, (u) => u.copyWith(progress: progress));
            },
          );
      if (!ref.mounted) return;
      _update(
        upload.localId,
        (u) => u.copyWith(status: UploadStatus.done, progress: 1),
      );
      ref.invalidate(incidentPhotosProvider(idIncident));
      unawaited(ref.read(incidentsProvider.notifier).refresh());
    } on AppException catch (e) {
      if (!ref.mounted) return;
      _update(
        upload.localId,
        (u) => u.copyWith(status: UploadStatus.failed, error: e),
      );
    }
  }

  void _update(String localId, PhotoUpload Function(PhotoUpload) change) {
    if (!ref.mounted) return;
    state = [
      for (final u in state) u.localId == localId ? change(u) : u,
    ];
  }
}

/// Photos encore possibles pour un incident (limite du backend : 10).
int remainingPhotoSlots({
  required int alreadyUploaded,
  required int pending,
}) => (Incident.maxPhotos - alreadyUploaded - pending).clamp(
  0,
  Incident.maxPhotos,
);
