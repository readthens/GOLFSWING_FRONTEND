import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';

final offlineQueueProvider = ChangeNotifierProvider<OfflineQueueStore>((ref) {
  final store = OfflineQueueStore();
  unawaited(store.load());
  return store;
});

enum OfflineQueueItemStatus { pending, syncing, failed }

bool shouldQueueOffline(Object error) {
  if (error is! DioException) return false;
  if (error.response != null) return false;
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.unknown => true,
    _ => false,
  };
}

class OfflineQueueItem {
  const OfflineQueueItem({
    required this.id,
    required this.action,
    required this.title,
    required this.payload,
    required this.createdAt,
    this.attemptCount = 0,
    this.lastError,
  });

  final String id;
  final String action;
  final String title;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attemptCount;
  final String? lastError;

  OfflineQueueItem copyWith({
    int? attemptCount,
    String? lastError,
    bool clearLastError = false,
  }) {
    return OfflineQueueItem(
      id: id,
      action: action,
      title: title,
      payload: payload,
      createdAt: createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'title': title,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'attempt_count': attemptCount,
      'last_error': lastError,
    }..removeWhere((_, value) => value == null);
  }

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) {
    return OfflineQueueItem(
      id: json['id'] as String,
      action: json['action'] as String,
      title: json['title'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
      attemptCount: json['attempt_count'] as int? ?? 0,
      lastError: json['last_error'] as String?,
    );
  }
}

abstract class OfflineQueuePersistence {
  Future<List<OfflineQueueItem>> read();
  Future<void> write(List<OfflineQueueItem> items);
}

class FileOfflineQueuePersistence implements OfflineQueuePersistence {
  const FileOfflineQueuePersistence();

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/swinglens_offline_queue.json');
  }

  @override
  Future<List<OfflineQueueItem>> read() async {
    final file = await _file();
    if (!file.existsSync()) return const [];
    final text = await file.readAsString();
    if (text.trim().isEmpty) return const [];
    final decoded = jsonDecode(text) as List<dynamic>;
    return decoded
        .map((item) => OfflineQueueItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> write(List<OfflineQueueItem> items) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}

class MemoryOfflineQueuePersistence implements OfflineQueuePersistence {
  List<OfflineQueueItem> _items = const [];

  @override
  Future<List<OfflineQueueItem>> read() async => List.unmodifiable(_items);

  @override
  Future<void> write(List<OfflineQueueItem> items) async {
    _items = List.unmodifiable(items);
  }
}

class OfflineQueueStore extends ChangeNotifier {
  OfflineQueueStore({
    OfflineQueuePersistence persistence = const FileOfflineQueuePersistence(),
  }) : _persistence = persistence;

  final OfflineQueuePersistence _persistence;
  final List<OfflineQueueItem> _items = [];
  bool _loaded = false;
  bool _isSyncing = false;
  String? _activeItemId;

  List<OfflineQueueItem> get items => List.unmodifiable(_items);
  int get pendingCount => _items.length;
  int get failedCount => _items.where(_isFailed).length;
  bool get isSyncing => _isSyncing;
  String? get activeItemId => _activeItemId;

  OfflineQueueItemStatus statusFor(OfflineQueueItem item) {
    if (_activeItemId == item.id) return OfflineQueueItemStatus.syncing;
    if (item.lastError != null && item.lastError!.trim().isNotEmpty) {
      return OfflineQueueItemStatus.failed;
    }
    return OfflineQueueItemStatus.pending;
  }

  Future<void> load() async {
    if (_loaded) return;
    _items
      ..clear()
      ..addAll(await _persistence.read());
    _loaded = true;
    notifyListeners();
  }

  Future<OfflineQueueItem> enqueue({
    required String action,
    required String title,
    required Map<String, dynamic> payload,
  }) async {
    await load();
    final item = OfflineQueueItem(
      id: _newId(action),
      action: action,
      title: title,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );
    _items.add(item);
    await _persist();
    return item;
  }

  Future<OfflineQueueItem> enqueueSwingUpload({
    required XFile file,
    required String club,
    required String angle,
    required String locationType,
    required String sessionType,
    required Map<String, dynamic> captureMetadata,
    int? durationMs,
    int? resolutionWidth,
    int? resolutionHeight,
  }) async {
    await load();
    final retained = await _retainUploadFile(file);
    return enqueue(
      action: 'upload.swing_video',
      title: 'Video upload queued',
      payload: {
        'local_file_path': retained.path,
        'file_name': file.name,
        'club': club,
        'angle': angle,
        'location_type': locationType,
        'session_type': sessionType,
        'capture_metadata': captureMetadata,
        'duration_ms': durationMs,
        'resolution_width': resolutionWidth,
        'resolution_height': resolutionHeight,
      }..removeWhere((_, value) => value == null),
    );
  }

  Future<void> retryAll({
    required String accessToken,
    required ApiClient apiClient,
  }) async {
    await load();
    if (_isSyncing || _items.isEmpty) return;
    _isSyncing = true;
    notifyListeners();
    try {
      for (final item in List<OfflineQueueItem>.from(_items)) {
        _activeItemId = item.id;
        notifyListeners();
        try {
          await _dispatch(item, accessToken: accessToken, apiClient: apiClient);
          _items.removeWhere((queued) => queued.id == item.id);
        } catch (error) {
          final index = _items.indexWhere((queued) => queued.id == item.id);
          if (index >= 0) {
            _items[index] = item.copyWith(
              attemptCount: item.attemptCount + 1,
              lastError: _shortError(error),
            );
          }
        }
        await _persist(notify: false);
      }
    } finally {
      _activeItemId = null;
      _isSyncing = false;
      await _persist();
    }
  }

  Future<void> remove(String id) async {
    await load();
    _items.removeWhere((item) => item.id == id);
    await _persist();
  }

  Future<void> clear() async {
    await load();
    _items.clear();
    await _persist();
  }

  Future<void> clearFailed() async {
    await load();
    _items.removeWhere(_isFailed);
    await _persist();
  }

  Future<void> _dispatch(
    OfflineQueueItem item, {
    required String accessToken,
    required ApiClient apiClient,
  }) async {
    switch (item.action) {
      case 'favorite.save':
        await apiClient.saveFavorite(
          accessToken,
          entityType: item.payload['entity_type'] as String,
          entityId: item.payload['entity_id'] as String,
          folderId: item.payload['folder_id'] as String?,
          note: item.payload['note'] as String?,
          metadata: Map<String, dynamic>.from(
            item.payload['metadata'] as Map? ?? const {},
          ),
          idempotencyKey: item.id,
        );
        return;
      case 'favorite.delete':
        await apiClient.deleteFavorite(
          accessToken,
          item.payload['favorite_id'] as String,
          idempotencyKey: item.id,
        );
        return;
      case 'round.update':
        await apiClient.updateRound(
          accessToken,
          item.payload['round_id'] as String,
          Map<String, dynamic>.from(item.payload['fields'] as Map),
          idempotencyKey: item.id,
        );
        return;
      case 'round.hole.update':
        await apiClient.updateRoundHole(
          accessToken,
          item.payload['round_id'] as String,
          item.payload['hole_number'] as int,
          Map<String, dynamic>.from(item.payload['fields'] as Map),
          idempotencyKey: item.id,
        );
        return;
      case 'upload.swing_video':
        final localPath = item.payload['local_file_path'] as String;
        final fileName = item.payload['file_name'] as String;
        final retainedFile = File(localPath);
        if (!retainedFile.existsSync()) {
          throw StateError(
            'Queued upload file is missing. Remove this item and record again.',
          );
        }
        await apiClient.uploadSwingVideo(
          accessToken: accessToken,
          file: XFile(localPath, name: fileName),
          club: item.payload['club'] as String,
          angle: item.payload['angle'] as String,
          locationType: item.payload['location_type'] as String,
          sessionType: item.payload['session_type'] as String? ?? 'analysis',
          durationMs: item.payload['duration_ms'] as int?,
          resolutionWidth: item.payload['resolution_width'] as int?,
          resolutionHeight: item.payload['resolution_height'] as int?,
          captureMetadata: UploadCaptureMetadata.fromJson(
            Map<String, dynamic>.from(item.payload['capture_metadata'] as Map),
          ),
          idempotencyKey: item.id,
        );
        await retainedFile.delete();
        return;
      default:
        throw StateError('Unsupported offline action: ${item.action}');
    }
  }

  Future<File> _retainUploadFile(XFile file) async {
    final directory = await getApplicationDocumentsDirectory();
    final queueDirectory = Directory(
      '${directory.path}/swinglens_queued_uploads',
    );
    if (!queueDirectory.existsSync()) {
      await queueDirectory.create(recursive: true);
    }
    final retained = File(
      '${queueDirectory.path}/${DateTime.now().microsecondsSinceEpoch}_${_safeFileName(file.name)}',
    );
    return File(file.path).copy(retained.path);
  }

  Future<void> _persist({bool notify = true}) async {
    await _persistence.write(_items);
    if (notify) notifyListeners();
  }

  String _newId(String action) {
    final safeAction = action.replaceAll(RegExp(r'[^A-Za-z0-9._:-]'), '-');
    return 'offline-$safeAction-${DateTime.now().microsecondsSinceEpoch}-${_items.length}';
  }

  String _shortError(Object error) {
    if (error is DioException) {
      return error.message ?? error.type.name;
    }
    return error.toString();
  }

  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'queued-video.mp4' : cleaned;
  }

  bool _isFailed(OfflineQueueItem item) {
    return item.lastError != null && item.lastError!.trim().isNotEmpty;
  }
}
