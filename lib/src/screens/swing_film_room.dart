import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/swing_overlay_painter.dart';

enum SwingFilmRoomMode { overview, detailed }

class SwingFilmRoom extends ConsumerStatefulWidget {
  const SwingFilmRoom({
    required this.result,
    required this.video,
    required this.accessToken,
    this.mode = SwingFilmRoomMode.detailed,
    this.onReviewChanged,
    super.key,
  });

  final AnalysisResult result;
  final SwingVideo video;
  final String accessToken;
  final SwingFilmRoomMode mode;
  final VoidCallback? onReviewChanged;

  @override
  ConsumerState<SwingFilmRoom> createState() => _SwingFilmRoomState();
}

class _SwingFilmRoomState extends ConsumerState<SwingFilmRoom> {
  AnalysisOverlayTrack? _track;
  VideoPlayerController? _controller;
  File? _tempVideoFile;
  bool _isLoading = true;
  String? _error;
  String? _playbackMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant SwingFilmRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.id != widget.result.id ||
        oldWidget.video.id != widget.video.id ||
        oldWidget.accessToken != widget.accessToken) {
      unawaited(_controller?.dispose());
      unawaited(_deleteTempVideo());
      _controller = null;
      _track = null;
      _error = null;
      _playbackMessage = null;
      _isLoading = true;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    unawaited(_deleteTempVideo());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final track = await api.getOverlayTrack(
        widget.accessToken,
        widget.result.id,
      );
      VideoPlayerController? controller;
      String? playbackMessage;
      try {
        final tempDir = await getTemporaryDirectory();
        final destination = File(
          '${tempDir.path}/swinglens_${widget.video.id}.mp4',
        );
        _tempVideoFile = destination;
        await api.downloadSwingVideoFile(
          accessToken: widget.accessToken,
          videoId: widget.video.id,
          destinationPath: destination.path,
        );
        controller = VideoPlayerController.file(destination);
        await controller.initialize();
        await controller.setLooping(false);
      } on MissingPluginException {
        playbackMessage = 'Video playback is unavailable in this test runtime.';
      } catch (_) {
        playbackMessage =
            'Video playback is unavailable, but pose overlays are ready.';
      }
      if (!mounted) {
        await controller?.dispose();
        return;
      }
      setState(() {
        _track = track;
        _controller = controller;
        _playbackMessage = playbackMessage;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load the film review track.';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTempVideo() async {
    final file = _tempVideoFile;
    _tempVideoFile = null;
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.mode == SwingFilmRoomMode.overview
        ? 'EVIDENCE REPLAY'
        : 'SWING FILM ROOM';
    if (_isLoading) {
      return InfoPanel(
        children: [
          Text(label, style: AppTextStyles.label),
          const LinearProgressIndicator(minHeight: 2),
        ],
      );
    }
    final track = _track;
    if (_error != null || track == null) {
      return InfoPanel(
        children: [
          Text(label, style: AppTextStyles.label),
          Text(_error ?? 'Film review is unavailable.'),
          PrimaryButton(label: 'RELOAD FILM ROOM', onPressed: _load),
        ],
      );
    }
    return SwingFilmRoomView(
      track: track,
      controller: _controller,
      playbackMessage: _playbackMessage,
      mode: widget.mode,
      onSaveReview: _saveReview,
      onResetReview: _resetReview,
    );
  }

  Future<void> _saveReview(Map<String, int> overrides) async {
    await ref
        .read(apiClientProvider)
        .saveEventReview(
          accessToken: widget.accessToken,
          resultId: widget.result.id,
          phaseOverrides: overrides.entries
              .map(
                (entry) => PhaseOverride(
                  phaseCode: entry.key,
                  timestampMs: entry.value,
                ),
              )
              .toList(),
        );
    await _load();
    widget.onReviewChanged?.call();
  }

  Future<void> _resetReview() async {
    await ref
        .read(apiClientProvider)
        .resetEventReview(
          accessToken: widget.accessToken,
          resultId: widget.result.id,
        );
    await _load();
    widget.onReviewChanged?.call();
  }
}

class SwingFilmRoomView extends StatefulWidget {
  const SwingFilmRoomView({
    required this.track,
    this.controller,
    this.playbackMessage,
    this.mode = SwingFilmRoomMode.detailed,
    this.onSaveReview,
    this.onResetReview,
    super.key,
  });

  final AnalysisOverlayTrack track;
  final VideoPlayerController? controller;
  final String? playbackMessage;
  final SwingFilmRoomMode mode;
  final Future<void> Function(Map<String, int> overrides)? onSaveReview;
  final Future<void> Function()? onResetReview;

  @override
  State<SwingFilmRoomView> createState() => _SwingFilmRoomViewState();
}

class _SwingFilmRoomViewState extends State<SwingFilmRoomView> {
  int _positionMs = 0;
  bool _isPlaying = false;
  bool _showSkeleton = true;
  bool _showSpine = true;
  bool _showGuides = true;
  bool _showFaultReference = true;
  double _speed = 1;
  OverlayFaultCheckpoint? _selectedFault;
  bool _isAdjusting = false;
  bool _isSavingReview = false;
  String _selectedPhaseCode = 'P1';
  String? _reviewMessage;
  Map<String, int> _draftOverrides = {};

  VideoPlayerController? get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _draftOverrides = _reviewedOverrides(widget.track);
    _controller?.addListener(_syncFromVideo);
    _syncFromVideo();
  }

  @override
  void didUpdateWidget(covariant SwingFilmRoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncFromVideo);
      widget.controller?.addListener(_syncFromVideo);
      _syncFromVideo();
    }
    if (oldWidget.track.resultId != widget.track.resultId ||
        oldWidget.track.checkpoints != widget.track.checkpoints) {
      _draftOverrides = _reviewedOverrides(widget.track);
      _reviewMessage = null;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncFromVideo);
    super.dispose();
  }

  void _syncFromVideo() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position.inMilliseconds;
    final duration = _durationMs;
    if (position > duration && controller.value.isPlaying) {
      unawaited(controller.pause());
      unawaited(controller.seekTo(Duration(milliseconds: duration)));
    }
    final playing = controller.value.isPlaying;
    if ((position - _positionMs).abs() < 55 && playing == _isPlaying) return;
    if (!mounted) return;
    setState(() {
      _positionMs = position.clamp(0, duration);
      _isPlaying = playing;
    });
  }

  int get _durationMs {
    final controller = _controller;
    final controllerDuration =
        controller != null && controller.value.isInitialized
        ? controller.value.duration.inMilliseconds
        : 0;
    final reviewDuration = widget.track.effectiveDurationMs;
    if (reviewDuration > 0 && controllerDuration > 0) {
      return reviewDuration < controllerDuration
          ? reviewDuration
          : controllerDuration;
    }
    if (reviewDuration > 0) return reviewDuration;
    return controllerDuration > 0 ? controllerDuration : 1;
  }

  OverlayFrame? get _activeFrame {
    final frames = widget.track.frames;
    if (frames.isEmpty) return null;
    return frames.reduce((best, frame) {
      final bestDistance = (best.timestampMs - _positionMs).abs();
      final frameDistance = (frame.timestampMs - _positionMs).abs();
      return frameDistance < bestDistance ? frame : best;
    });
  }

  OverlayCheckpoint? get _activePhase {
    final checkpoints = widget.track.checkpoints;
    if (checkpoints.isEmpty) return null;
    final nearest = checkpoints.reduce((best, item) {
      final bestDistance = (best.timestampMs - _positionMs).abs();
      final itemDistance = (item.timestampMs - _positionMs).abs();
      return itemDistance < bestDistance ? item : best;
    });
    return (nearest.timestampMs - _positionMs).abs() <= 700 ? nearest : null;
  }

  OverlayFaultCheckpoint? get _activeFault {
    final selected = _selectedFault;
    if (selected != null) return selected;
    return _nearestFaultAt(_positionMs);
  }

  OverlayFaultCheckpoint? _nearestFaultAt(int positionMs) {
    final faults = widget.track.faultCheckpoints;
    if (faults.isEmpty) return null;
    final nearest = faults.reduce((best, item) {
      final bestDistance = (best.timestampMs - positionMs).abs();
      final itemDistance = (item.timestampMs - positionMs).abs();
      return itemDistance < bestDistance ? item : best;
    });
    return (nearest.timestampMs - positionMs).abs() <= 1100 ? nearest : null;
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    _syncFromVideo();
  }

  Future<void> _seekTo(int positionMs) async {
    final clamped = positionMs.clamp(0, _durationMs);
    setState(() {
      _positionMs = clamped;
      _selectedFault = _nearestFaultAt(clamped);
    });
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.seekTo(Duration(milliseconds: clamped));
    }
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.setPlaybackSpeed(speed);
    }
  }

  void _setSelectedPhaseAtCurrentPosition() {
    setState(() {
      _draftOverrides = {..._draftOverrides, _selectedPhaseCode: _positionMs};
      _reviewMessage = 'SET $_selectedPhaseCode AT ${_timeLabel(_positionMs)}';
    });
  }

  Future<void> _saveReview() async {
    final saveReview = widget.onSaveReview;
    if (saveReview == null || _draftOverrides.isEmpty || _isSavingReview) {
      return;
    }
    setState(() {
      _isSavingReview = true;
      _reviewMessage = null;
    });
    try {
      await saveReview(_draftOverrides);
      if (!mounted) return;
      setState(() {
        _isSavingReview = false;
        _isAdjusting = false;
        _reviewMessage = 'REVIEW SAVED';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSavingReview = false;
        _reviewMessage = 'UNABLE TO SAVE REVIEW';
      });
    }
  }

  Future<void> _resetReview() async {
    final resetReview = widget.onResetReview;
    if (resetReview == null || _isSavingReview) return;
    setState(() {
      _isSavingReview = true;
      _reviewMessage = null;
    });
    try {
      await resetReview();
      if (!mounted) return;
      setState(() {
        _draftOverrides = {};
        _isSavingReview = false;
        _isAdjusting = false;
        _reviewMessage = 'DETECTION RESTORED';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSavingReview = false;
        _reviewMessage = 'UNABLE TO RESET REVIEW';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _activeFrame;
    final phase = _activePhase;
    final fault = _activeFault;
    final duration = _durationMs;
    final isOverview = widget.mode == SwingFilmRoomMode.overview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOverview ? 'EVIDENCE REPLAY' : 'SWING FILM ROOM',
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('film-room-video-surface'),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: widget.track.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _VideoLayer(controller: _controller),
                if (frame != null)
                  CustomPaint(
                    painter: SwingOverlayPainter(
                      overlay: frame.toPainterOverlay(),
                      segments: widget.track.segments,
                      showSkeleton: _showSkeleton,
                      showSpine: _showSpine,
                      showGuides: _showGuides,
                      showFaultReference: _showFaultReference,
                    ),
                  ),
                Positioned(
                  left: 10,
                  top: 10,
                  right: 10,
                  child: _FilmBadges(
                    phase: phase,
                    fault: fault,
                    frame: frame,
                    playbackMessage: widget.playbackMessage,
                  ),
                ),
                if (isOverview)
                  Center(
                    child: _OverviewPlayButton(
                      isPlaying: _isPlaying,
                      canPlay: _controller?.value.isInitialized ?? false,
                      onPressed: _togglePlay,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isOverview)
          _OverviewTimeline(positionMs: _positionMs, durationMs: duration)
        else ...[
          _TransportControls(
            isPlaying: _isPlaying,
            canPlay: _controller?.value.isInitialized ?? false,
            positionMs: _positionMs,
            durationMs: duration,
            speed: _speed,
            checkpoints: widget.track.checkpoints,
            faultCheckpoints: widget.track.faultCheckpoints,
            onPlayPause: _togglePlay,
            onSeek: _seekTo,
            onSpeed: _setSpeed,
          ),
          const SizedBox(height: 12),
          _OverlayToggles(
            showSkeleton: _showSkeleton,
            showSpine: _showSpine,
            showGuides: _showGuides,
            showFaultReference: _showFaultReference,
            onSkeleton: (value) => setState(() => _showSkeleton = value),
            onSpine: (value) => setState(() => _showSpine = value),
            onGuides: (value) => setState(() => _showGuides = value),
            onFaultReference: (value) =>
                setState(() => _showFaultReference = value),
          ),
          const SizedBox(height: 12),
          _EventReviewControls(
            isAdjusting: _isAdjusting,
            selectedPhaseCode: _selectedPhaseCode,
            positionMs: _positionMs,
            draftOverrides: _draftOverrides,
            checkpoints: widget.track.checkpoints,
            isSaving: _isSavingReview,
            message: _reviewMessage,
            canPersist:
                widget.onSaveReview != null && widget.onResetReview != null,
            onToggleAdjust: () => setState(() => _isAdjusting = !_isAdjusting),
            onSelectPhase: (value) =>
                setState(() => _selectedPhaseCode = value),
            onSetPhase: _setSelectedPhaseAtCurrentPosition,
            onSave: _saveReview,
            onReset: _resetReview,
          ),
          if (fault != null) ...[
            const SizedBox(height: 12),
            _FaultFilmPanel(fault: fault),
          ],
        ],
      ],
    );
  }
}

class SwingVideoPreviewSurface extends ConsumerStatefulWidget {
  const SwingVideoPreviewSurface({
    required this.video,
    required this.accessToken,
    this.aspectRatio = 16 / 9,
    this.overlay,
    super.key,
  });

  final SwingVideo video;
  final String accessToken;
  final double aspectRatio;
  final Widget? overlay;

  @override
  ConsumerState<SwingVideoPreviewSurface> createState() =>
      _SwingVideoPreviewSurfaceState();
}

class _SwingVideoPreviewSurfaceState
    extends ConsumerState<SwingVideoPreviewSurface> {
  VideoPlayerController? _controller;
  File? _tempVideoFile;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant SwingVideoPreviewSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.accessToken != widget.accessToken) {
      unawaited(_controller?.dispose());
      unawaited(_deleteTempVideo());
      _controller = null;
      _message = null;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    unawaited(_deleteTempVideo());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final destination = File(
        '${tempDir.path}/swinglens_preview_${widget.video.id}.mp4',
      );
      _tempVideoFile = destination;
      await ref
          .read(apiClientProvider)
          .downloadSwingVideoFile(
            accessToken: widget.accessToken,
            videoId: widget.video.id,
            destinationPath: destination.path,
          );
      final controller = VideoPlayerController.file(destination);
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _message = 'VIDEO PREVIEW UNAVAILABLE');
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'VIDEO PREVIEW UNAVAILABLE');
    }
  }

  Future<void> _deleteTempVideo() async {
    final file = _tempVideoFile;
    _tempVideoFile = null;
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _VideoLayer(controller: _controller),
            if (widget.overlay != null) widget.overlay!,
            if (_message != null)
              Positioned(left: 10, top: 10, child: _Badge(label: _message!)),
          ],
        ),
      ),
    );
  }
}

class _OverviewPlayButton extends StatelessWidget {
  const _OverviewPlayButton({
    required this.isPlaying,
    required this.canPlay,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool canPlay;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        border: Border.all(color: AppColors.border),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: isPlaying ? 'Pause replay' : 'Play replay',
        iconSize: 34,
        onPressed: canPlay ? onPressed : null,
        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}

class _OverviewTimeline extends StatelessWidget {
  const _OverviewTimeline({required this.positionMs, required this.durationMs});

  final int positionMs;
  final int durationMs;

  @override
  Widget build(BuildContext context) {
    final progress = durationMs <= 0
        ? 0.0
        : (positionMs / durationMs).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          semanticsLabel: 'Replay progress',
          semanticsValue: (progress * 100).round().toString(),
        ),
        const SizedBox(height: 8),
        Text(
          '${_timeLabel(positionMs)} / ${_timeLabel(durationMs)}',
          style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _VideoLayer extends StatelessWidget {
  const _VideoLayer({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Icon(
          Icons.sports_golf,
          color: Colors.white.withValues(alpha: 0.16),
          size: 72,
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _FilmBadges extends StatelessWidget {
  const _FilmBadges({
    required this.phase,
    required this.fault,
    required this.frame,
    required this.playbackMessage,
  });

  final OverlayCheckpoint? phase;
  final OverlayFaultCheckpoint? fault;
  final OverlayFrame? frame;
  final String? playbackMessage;

  @override
  Widget build(BuildContext context) {
    final metrics = frame?.metrics ?? const {};
    final eventLabel = _eventStatusLabel(phase);
    final eventNeedsReview = _eventNeedsReview(phase);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        _Badge(
          label:
              fault?.label.toUpperCase() ??
              phase?.phaseCode.toUpperCase() ??
              'LIVE REVIEW',
          accent: fault == null
              ? AppColors.textPrimary
              : const Color(0xFFFFC857),
        ),
        if (eventLabel != null)
          _Badge(
            label: eventLabel,
            accent: eventNeedsReview
                ? const Color(0xFFFFC857)
                : const Color(0xFFB9FF66),
          ),
        if (metrics['spine_angle_degrees'] != null)
          _Badge(
            label:
                'SPINE ${metrics['spine_angle_degrees']!.toStringAsFixed(1)}°',
            accent: const Color(0xFFB9FF66),
          ),
        if (metrics['lead_elbow_angle_degrees'] != null)
          _Badge(
            label:
                'LEAD ARM ${metrics['lead_elbow_angle_degrees']!.toStringAsFixed(0)}°',
            accent: AppColors.textSecondary,
          ),
        if (metrics['stance_width_body_widths'] != null)
          _Badge(
            label:
                'STANCE ${metrics['stance_width_body_widths']!.toStringAsFixed(2)} BW',
            accent: AppColors.textSecondary,
          ),
        if (metrics['arm_extension_body_widths'] != null)
          _Badge(
            label:
                'EXT ${metrics['arm_extension_body_widths']!.toStringAsFixed(2)} BW',
            accent: AppColors.textSecondary,
          ),
        if (metrics['body_plane_tilt_degrees'] != null)
          _Badge(
            label:
                'BODY PLANE ${metrics['body_plane_tilt_degrees']!.toStringAsFixed(0)}°',
            accent: AppColors.textSecondary,
          ),
        if (metrics['hand_plane_proxy_degrees'] != null)
          _Badge(
            label:
                'HAND LINE ${metrics['hand_plane_proxy_degrees']!.toStringAsFixed(0)}°',
            accent: AppColors.textSecondary,
          ),
        if (metrics['hip_center_x'] != null)
          _Badge(
            label: 'HIP X ${metrics['hip_center_x']!.toStringAsFixed(2)}',
            accent: AppColors.textSecondary,
          ),
        if (playbackMessage != null) _Badge(label: playbackMessage!),
      ],
    );
  }
}

String? _eventStatusLabel(OverlayCheckpoint? phase) {
  if (phase == null) return null;
  if (phase.source == 'reviewed') return 'REVIEWED EVENT';
  if (_eventNeedsReview(phase)) return 'NEEDS REVIEW';
  final confidence = phase.confidence;
  if (confidence == null) return null;
  return 'EVENT ${(confidence * 100).round()}%';
}

Map<String, int> _reviewedOverrides(AnalysisOverlayTrack track) {
  return {
    for (final checkpoint in track.checkpoints)
      if (checkpoint.source == 'reviewed')
        checkpoint.phaseCode: checkpoint.timestampMs,
  };
}

bool _eventNeedsReview(OverlayCheckpoint? phase) {
  if (phase == null) return false;
  final status = phase.detectionStatus;
  return status == 'fallback' ||
      status == 'low_confidence' ||
      ((phase.confidence ?? 1) < 0.55);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.accent = AppColors.textSecondary});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        border: Border.all(color: accent.withValues(alpha: 0.52)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.micro.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.isPlaying,
    required this.canPlay,
    required this.positionMs,
    required this.durationMs,
    required this.speed,
    required this.checkpoints,
    required this.faultCheckpoints,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSpeed,
  });

  final bool isPlaying;
  final bool canPlay;
  final int positionMs;
  final int durationMs;
  final double speed;
  final List<OverlayCheckpoint> checkpoints;
  final List<OverlayFaultCheckpoint> faultCheckpoints;
  final VoidCallback onPlayPause;
  final ValueChanged<int> onSeek;
  final ValueChanged<double> onSpeed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: isPlaying ? 'Pause' : 'Play',
                onPressed: canPlay ? onPlayPause : null,
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: 'Back 0.1 seconds',
                onPressed: () => onSeek(positionMs - 100),
                icon: const Icon(Icons.keyboard_arrow_left),
              ),
              IconButton(
                tooltip: 'Forward 0.1 seconds',
                onPressed: () => onSeek(positionMs + 100),
                icon: const Icon(Icons.keyboard_arrow_right),
              ),
              const SizedBox(width: 8),
              Text(
                '${_timeLabel(positionMs)} / ${_timeLabel(durationMs)}',
                style: AppTextStyles.micro,
              ),
            ],
          ),
          _TimelineSlider(
            positionMs: positionMs,
            durationMs: durationMs,
            checkpoints: checkpoints,
            faultCheckpoints: faultCheckpoints,
            onSeek: onSeek,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in checkpoints)
                ActionChip(
                  key: ValueKey('phase-chip-${item.phaseCode}'),
                  label: Text(
                    item.source == 'reviewed'
                        ? '${item.phaseCode} REVIEWED'
                        : item.phaseCode,
                  ),
                  onPressed: () => onSeek(item.timestampMs),
                ),
              for (final item in faultCheckpoints.take(3))
                ActionChip(
                  key: ValueKey('fault-chip-${item.code}'),
                  avatar: const Icon(Icons.warning_amber, size: 16),
                  label: Text(item.label.toUpperCase()),
                  onPressed: () => onSeek(item.timestampMs),
                ),
              for (final value in const [0.25, 0.5, 1.0])
                ChoiceChip(
                  key: ValueKey('speed-chip-$value'),
                  label: Text('${value.toStringAsFixed(value == 1 ? 0 : 2)}X'),
                  selected: speed == value,
                  onSelected: (_) => onSpeed(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineSlider extends StatelessWidget {
  const _TimelineSlider({
    required this.positionMs,
    required this.durationMs,
    required this.checkpoints,
    required this.faultCheckpoints,
    required this.onSeek,
  });

  final int positionMs;
  final int durationMs;
  final List<OverlayCheckpoint> checkpoints;
  final List<OverlayFaultCheckpoint> faultCheckpoints;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CustomPaint(
                  painter: _TimelineTickPainter(
                    durationMs: durationMs,
                    phaseTicks: checkpoints.map((item) => item.timestampMs),
                    faultTicks: faultCheckpoints.map(
                      (item) => item.timestampMs,
                    ),
                  ),
                ),
              ),
            ),
            Slider(
              key: const ValueKey('film-room-slider'),
              value: positionMs.clamp(0, durationMs).toDouble(),
              min: 0,
              max: durationMs.toDouble(),
              onChanged: (value) => onSeek(value.round()),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineTickPainter extends CustomPainter {
  const _TimelineTickPainter({
    required this.durationMs,
    required this.phaseTicks,
    required this.faultTicks,
  });

  final int durationMs;
  final Iterable<int> phaseTicks;
  final Iterable<int> faultTicks;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationMs <= 0) return;
    final phasePaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.72)
      ..strokeWidth = 2;
    final faultPaint = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.9)
      ..strokeWidth = 3;
    for (final tick in phaseTicks) {
      final x = (tick / durationMs).clamp(0, 1) * size.width;
      canvas.drawLine(Offset(x, 8), Offset(x, size.height - 8), phasePaint);
    }
    for (final tick in faultTicks) {
      final x = (tick / durationMs).clamp(0, 1) * size.width;
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), faultPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineTickPainter oldDelegate) {
    return oldDelegate.durationMs != durationMs ||
        oldDelegate.phaseTicks != phaseTicks ||
        oldDelegate.faultTicks != faultTicks;
  }
}

class _OverlayToggles extends StatelessWidget {
  const _OverlayToggles({
    required this.showSkeleton,
    required this.showSpine,
    required this.showGuides,
    required this.showFaultReference,
    required this.onSkeleton,
    required this.onSpine,
    required this.onGuides,
    required this.onFaultReference,
  });

  final bool showSkeleton;
  final bool showSpine;
  final bool showGuides;
  final bool showFaultReference;
  final ValueChanged<bool> onSkeleton;
  final ValueChanged<bool> onSpine;
  final ValueChanged<bool> onGuides;
  final ValueChanged<bool> onFaultReference;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('SKELETON'),
          selected: showSkeleton,
          onSelected: onSkeleton,
        ),
        FilterChip(
          label: const Text('SPINE'),
          selected: showSpine,
          onSelected: onSpine,
        ),
        FilterChip(
          label: const Text('HIPS / SHOULDERS'),
          selected: showGuides,
          onSelected: onGuides,
        ),
        FilterChip(
          label: const Text('FAULT LINE'),
          selected: showFaultReference,
          onSelected: onFaultReference,
        ),
      ],
    );
  }
}

class _EventReviewControls extends StatelessWidget {
  const _EventReviewControls({
    required this.isAdjusting,
    required this.selectedPhaseCode,
    required this.positionMs,
    required this.draftOverrides,
    required this.checkpoints,
    required this.isSaving,
    required this.canPersist,
    required this.onToggleAdjust,
    required this.onSelectPhase,
    required this.onSetPhase,
    required this.onSave,
    required this.onReset,
    this.message,
  });

  final bool isAdjusting;
  final String selectedPhaseCode;
  final int positionMs;
  final Map<String, int> draftOverrides;
  final List<OverlayCheckpoint> checkpoints;
  final bool isSaving;
  final bool canPersist;
  final VoidCallback onToggleAdjust;
  final ValueChanged<String> onSelectPhase;
  final VoidCallback onSetPhase;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final reviewedCount = checkpoints
        .where((checkpoint) => checkpoint.source == 'reviewed')
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reviewedCount > 0
                      ? 'EVENT REVIEW · $reviewedCount REVIEWED'
                      : 'EVENT REVIEW',
                  style: AppTextStyles.label,
                ),
              ),
              TextButton.icon(
                onPressed: onToggleAdjust,
                icon: Icon(isAdjusting ? Icons.close : Icons.tune),
                label: Text(isAdjusting ? 'CLOSE' : 'ADJUST EVENTS'),
              ),
            ],
          ),
          if (isAdjusting) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final phaseCode in const ['P1', 'P4', 'P7', 'P10'])
                  ChoiceChip(
                    key: ValueKey('review-phase-$phaseCode'),
                    label: Text(
                      draftOverrides[phaseCode] == null
                          ? phaseCode
                          : '$phaseCode ${_timeLabel(draftOverrides[phaseCode]!)}',
                    ),
                    selected: selectedPhaseCode == phaseCode,
                    onSelected: (_) => onSelectPhase(phaseCode),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  key: const ValueKey('set-review-phase'),
                  onPressed: onSetPhase,
                  icon: const Icon(Icons.flag),
                  label: Text('SET $selectedPhaseCode'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('save-event-review'),
                  onPressed:
                      canPersist && draftOverrides.isNotEmpty && !isSaving
                      ? onSave
                      : null,
                  icon: const Icon(Icons.save),
                  label: Text(isSaving ? 'SAVING...' : 'SAVE REVIEW'),
                ),
                TextButton.icon(
                  key: const ValueKey('reset-event-review'),
                  onPressed: canPersist && !isSaving ? onReset : null,
                  icon: const Icon(Icons.restore),
                  label: const Text('RESET DETECTION'),
                ),
              ],
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, style: AppTextStyles.micro),
          ],
        ],
      ),
    );
  }
}

class _FaultFilmPanel extends StatelessWidget {
  const _FaultFilmPanel({required this.fault});

  final OverlayFaultCheckpoint fault;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Text(
          fault.isPrimary ? 'PRIMARY MISTAKE MOMENT' : 'MISTAKE MOMENT',
          style: AppTextStyles.label,
        ),
        Text(fault.label.toUpperCase()),
        if (fault.evidence != null) Text('WHAT HAPPENED: ${fault.evidence}'),
        Text(
          'WHY IT MATTERS: This checkpoint marks where the current pose evidence is strongest in the swing flow.',
        ),
        if (fault.drill != null) Text('FIX DRILL: ${fault.drill}'),
        if (fault.nextGoal != null) Text('NEXT SWING GOAL: ${fault.nextGoal}'),
      ],
    );
  }
}

String _timeLabel(int milliseconds) {
  final totalTenths = (milliseconds / 100).round();
  final seconds = totalTenths ~/ 10;
  final tenths = totalTenths % 10;
  return '$seconds.$tenths';
}
