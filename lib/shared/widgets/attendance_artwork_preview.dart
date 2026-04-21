import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';

class AttendanceArtworkPreview extends StatefulWidget {
  final String imagePath;
  final String title;
  final String emptyLabel;

  const AttendanceArtworkPreview({
    super.key,
    required this.imagePath,
    this.title = '课堂作品',
    this.emptyLabel = '作品文件不可用，请重新上传。',
  });

  @override
  State<AttendanceArtworkPreview> createState() =>
      _AttendanceArtworkPreviewState();
}

class _AttendanceArtworkPreviewState extends State<AttendanceArtworkPreview> {
  late String _normalizedPath;
  late Future<bool> _hasImageFileFuture;

  @override
  void initState() {
    super.initState();
    _updateImagePath();
  }

  @override
  void didUpdateWidget(covariant AttendanceArtworkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath == widget.imagePath) return;
    _updateImagePath();
  }

  void _updateImagePath() {
    _normalizedPath = widget.imagePath.trim();
    _hasImageFileFuture = _normalizedPath.isEmpty
        ? Future<bool>.value(false)
        : File(_normalizedPath).exists();
  }

  @override
  Widget build(BuildContext context) {
    if (_normalizedPath.isEmpty) {
      return const SizedBox.shrink();
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return FutureBuilder<bool>(
      future: _hasImageFileFuture,
      builder: (context, snapshot) {
        final hasImageFile = snapshot.data ?? false;
        final imageFile = File(_normalizedPath);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kPrimaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: hasImageFile ? '${widget.title}，点击查看原图' : widget.emptyLabel,
              button: hasImageFile,
              image: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: hasImageFile
                    ? () => showAttendanceArtworkPreviewDialog(
                        context,
                        imagePath: _normalizedPath,
                        title: widget.title,
                      )
                    : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimaryBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: kPrimaryBlue.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: hasImageFile
                              ? RepaintBoundary(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final logicalWidth =
                                          constraints.maxWidth.isFinite
                                          ? constraints.maxWidth
                                          : MediaQuery.sizeOf(context).width;
                                      final cacheWidth =
                                          (logicalWidth * devicePixelRatio)
                                              .round()
                                              .clamp(160, 1200)
                                              .toInt();
                                      final cacheHeight =
                                          (cacheWidth * 3 / 4).round();

                                      return Image.file(
                                        imageFile,
                                        fit: BoxFit.cover,
                                        cacheWidth: cacheWidth,
                                        cacheHeight: cacheHeight,
                                        filterQuality: FilterQuality.low,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _ArtworkUnavailable(
                                                  label: widget.emptyLabel,
                                                ),
                                      );
                                    },
                                  ),
                                )
                              : _ArtworkUnavailable(label: widget.emptyLabel),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.open_in_full_outlined,
                            size: 16,
                            color: kPrimaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              hasImageFile ? '点击查看原图' : widget.emptyLabel,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: hasImageFile
                                        ? kPrimaryBlue
                                        : kInkSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> showAttendanceArtworkPreviewDialog(
  BuildContext context, {
  required String imagePath,
  String title = '课堂作品',
}) async {
  final imageFile = File(imagePath);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(dialogContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: 0.04),
                    child: imageFile.existsSync()
                        ? InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4,
                            child: Center(
                              child: Image.file(
                                imageFile,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const _ArtworkUnavailable(
                                      label: '作品文件不可读取，请重新上传。',
                                    ),
                              ),
                            ),
                          )
                        : const _ArtworkUnavailable(
                            label: '作品文件不存在，请重新上传。',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ArtworkUnavailable extends StatelessWidget {
  final String label;

  const _ArtworkUnavailable({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: kInkSecondary),
      ),
    );
  }
}