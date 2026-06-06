import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _picker = ImagePicker();
  String _club = '7 iron';
  String _angle = 'down_the_line';
  XFile? _file;
  bool _isUploading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).state;
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/home'),
              ),
              const Text('UPLOAD SWING', style: AppTextStyles.title),
              const SizedBox(height: 12),
              Text(
                'Phase 1 uses device video selection. Guided capture arrives next.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 22),
              if (!auth.hasVideoConsent)
                InfoPanel(
                  children: [
                    const Text('Video-processing consent is required before upload.'),
                    GhostButton(
                      label: 'REVIEW CONSENT',
                      onPressed: () => context.go('/onboarding/privacy-consent'),
                    ),
                  ],
                )
              else ...[
                const Text('ANGLE', style: AppTextStyles.label),
                const SizedBox(height: 10),
                SegmentedChoices(
                  values: const ['face_on', 'down_the_line', 'rear_tracer'],
                  selected: _angle,
                  onSelected: (value) => setState(() => _angle = value),
                ),
                const SizedBox(height: 18),
                const Text('CLUB', style: AppTextStyles.label),
                const SizedBox(height: 10),
                SegmentedChoices(
                  values: const ['7 iron', 'driver', 'wedge'],
                  selected: _club,
                  onSelected: (value) => setState(() => _club = value),
                ),
                const SizedBox(height: 18),
                GhostButton(label: _file == null ? 'CHOOSE VIDEO' : _file!.name.toUpperCase(), onPressed: _pickVideo),
                const SizedBox(height: 16),
                if (_error != null) ErrorText(_error!),
                PrimaryButton(
                  label: _isUploading ? 'UPLOADING' : 'UPLOAD SWING',
                  onPressed: _file == null || _isUploading ? null : () => _upload(auth.accessToken),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _file = video;
        _error = null;
      });
    }
  }

  Future<void> _upload(String? token) async {
    if (token == null || _file == null) return;
    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      final session = await ref.read(apiClientProvider).uploadSwingVideo(
            accessToken: token,
            file: _file!,
            club: _club,
            angle: _angle,
          );
      if (mounted) context.go('/swings/${session.id}');
    } catch (_) {
      setState(() {
        _error = 'Upload failed. Confirm the backend and storage services are running.';
        _isUploading = false;
      });
    }
  }
}

