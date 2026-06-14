import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models.dart';
import '../offline/offline_queue.dart';
import 'app_chrome.dart';

class FavoriteToggleButton extends ConsumerStatefulWidget {
  const FavoriteToggleButton({
    required this.accessToken,
    required this.entityType,
    required this.entityId,
    this.saveLabel = 'SAVE FAVORITE',
    this.savedLabel = 'SAVED FAVORITE',
    super.key,
  });

  final String accessToken;
  final String entityType;
  final String entityId;
  final String saveLabel;
  final String savedLabel;

  @override
  ConsumerState<FavoriteToggleButton> createState() =>
      _FavoriteToggleButtonState();
}

class _FavoriteToggleButtonState extends ConsumerState<FavoriteToggleButton> {
  FavoriteItem? _favorite;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isQueued = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FavoriteToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken ||
        oldWidget.entityType != widget.entityType ||
        oldWidget.entityId != widget.entityId) {
      setState(() {
        _favorite = null;
        _isLoading = true;
      });
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final favorites = await ref
          .read(apiClientProvider)
          .getFavorites(
            widget.accessToken,
            entityType: widget.entityType,
            entityId: widget.entityId,
          );
      if (!mounted) return;
      setState(() {
        _favorite = favorites.isEmpty ? null : favorites.first;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggle() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      final existing = _favorite;
      if (existing == null) {
        final favorite = await api.saveFavorite(
          widget.accessToken,
          entityType: widget.entityType,
          entityId: widget.entityId,
        );
        if (mounted) {
          setState(() {
            _favorite = favorite;
            _isQueued = false;
          });
        }
      } else {
        await api.deleteFavorite(widget.accessToken, existing.id);
        if (mounted) {
          setState(() {
            _favorite = null;
            _isQueued = false;
          });
        }
      }
    } catch (error) {
      if (shouldQueueOffline(error)) {
        await _queueFavoriteToggle(existing: _favorite);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update favorite.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = _favorite != null;
    final label = _isLoading || _isSaving
        ? 'SYNCING...'
        : _isQueued
        ? 'SYNC QUEUED'
        : isSaved
        ? widget.savedLabel
        : widget.saveLabel;
    return GhostButton(
      label: label,
      onPressed: _isLoading || _isQueued ? null : _toggle,
    );
  }

  Future<void> _queueFavoriteToggle({FavoriteItem? existing}) async {
    final queue = ref.read(offlineQueueProvider);
    final ownerUserId = ref.read(authControllerProvider).state.user?.id;
    if (existing == null) {
      await queue.enqueue(
        action: 'favorite.save',
        title: '${widget.saveLabel} queued',
        ownerUserId: ownerUserId,
        payload: {
          'entity_type': widget.entityType,
          'entity_id': widget.entityId,
          'metadata': <String, dynamic>{},
        },
      );
    } else {
      await queue.enqueue(
        action: 'favorite.delete',
        title: '${widget.savedLabel} removal queued',
        ownerUserId: ownerUserId,
        payload: {'favorite_id': existing.id},
      );
    }
    if (!mounted) return;
    setState(() {
      _favorite = existing == null ? _favorite : null;
      _isQueued = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved offline. Sync will retry later.')),
    );
  }
}
