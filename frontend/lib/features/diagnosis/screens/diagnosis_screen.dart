import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../providers/diagnosis_provider.dart';

/// Diagnosis screen for capturing full outfit photo
class DiagnosisScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialImageData;

  const DiagnosisScreen({super.key, this.initialImageData});

  @override
  ConsumerState<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends ConsumerState<DiagnosisScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String? _capturedImagePath;
  Uint8List? _capturedImageBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(diagnosisProvider.notifier).reset();
      if (widget.initialImageData != null) {
        // Use image passed from home screen
        final path = widget.initialImageData!['path'] as String;
        final bytes = widget.initialImageData!['bytes'] as Uint8List;
        setState(() {
          _capturedImagePath = path;
          _capturedImageBytes = bytes;
        });
        ref.read(diagnosisProvider.notifier).setImageFromBytes(path, bytes);
      } else {
        _captureImage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final diagnosisState = ref.watch(diagnosisProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview / captured image
            _buildImagePreview(),

            // Top bar
            _buildTopBar(),

            // Full body guide frame
            if (_capturedImagePath == null) _buildGuideFrame(),

            // Bottom controls
            _buildBottomControls(diagnosisState),

            // Loading overlay
            if (diagnosisState.isAnalyzing) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_capturedImageBytes != null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: MemoryImage(_capturedImageBytes!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.backgroundDark,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: Colors.white24,
            ),
            SizedBox(height: 16),
            Text(
              '全身写真を撮影',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Text(
              'コーデ診断',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideFrame() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.accessibility_new,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'ここに立って全身を撮影',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '頭からつま先まで全身を写してください',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(DiagnosisState state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: _capturedImagePath == null
            ? _buildCaptureControls()
            : _buildAnalyzeControls(state),
      ),
    );
  }

  Widget _buildCaptureControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Gallery button
        _buildControlButton(
          icon: Icons.photo_library_outlined,
          label: 'ギャラリー',
          onTap: _pickFromGallery,
        ),

        // Capture button
        GestureDetector(
          onTap: _isProcessing ? null : _captureImage,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 4,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: _isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : null,
            ),
          ),
        ),

        // Spacer for balance
        const SizedBox(width: 60),
      ],
    );
  }

  Widget _buildAnalyzeControls(DiagnosisState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Retake button
            _buildControlButton(
              icon: Icons.refresh,
              label: '撮り直し',
              onTap: _retakePhoto,
            ),

            // Analyze button
            GestureDetector(
              onTap: state.isAnalyzing ? null : _analyzeOutfit,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'コーデを分析',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Placeholder for balance
            const SizedBox(width: 60),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            SizedBox(height: 24),
            Text(
              'コーデを分析中...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '少々お待ちください',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    setState(() => _isProcessing = true);

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedImagePath = photo.path;
          _capturedImageBytes = bytes;
        });
        ref.read(diagnosisProvider.notifier).setImageFromBytes(photo.path, bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像の撮影に失敗しました: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isProcessing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() {
          _capturedImagePath = image.path;
          _capturedImageBytes = bytes;
        });
        ref.read(diagnosisProvider.notifier).setImageFromBytes(image.path, bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像の選択に失敗しました: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImagePath = null;
      _capturedImageBytes = null;
    });
    ref.read(diagnosisProvider.notifier).reset();
    _captureImage();
  }

  Future<void> _analyzeOutfit() async {
    await ref.read(diagnosisProvider.notifier).analyzeOutfit();

    if (!mounted) return;

    final state = ref.read(diagnosisProvider);
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } else if (state.result != null) {
      context.goDiagnosisResult(state.result!);
    }
  }

  void _showTips() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'きれいに撮るコツ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTipItem(Icons.accessibility_new, '全身を頭からつま先まで写す'),
            _buildTipItem(Icons.wb_sunny_outlined, '自然光で明るく撮影'),
            _buildTipItem(Icons.crop_free, '無地の背景の前に立つ'),
            _buildTipItem(Icons.straighten, 'まっすぐ正面を向く'),
            _buildTipItem(Icons.timer, 'タイマーか他の人に撮ってもらう'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
