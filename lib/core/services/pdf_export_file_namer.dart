class PdfExportFileNamer {
  const PdfExportFileNamer();

  static final _invalidFileNameChars = RegExp(r'[\\/:*?"<>|]');
  static final _fileNameWhitespace = RegExp(r'\s+');
  static final _fileNameUnderscores = RegExp(r'_+');
  static final _leadingTrailingDotsAndUnderscores = RegExp(r'^[._]+|[._]+$');

  String sanitizeSegment(String value, {required String fallback}) {
    final sanitized = value
        .trim()
        .replaceAll(_invalidFileNameChars, '_')
        .replaceAll(_fileNameWhitespace, '_')
        .replaceAll(_fileNameUnderscores, '_')
        .replaceAll(_leadingTrailingDotsAndUnderscores, '');
    return sanitized.isEmpty ? fallback : sanitized;
  }

  String formatFileStamp(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '${time.year}$month$day$hour$minute$second';
  }

  String buildFileName({
    required String studentName,
    required String from,
    required String to,
    DateTime? timestamp,
  }) {
    final safeStudentName = sanitizeSegment(studentName, fallback: 'student');
    final safeFrom = sanitizeSegment(from, fallback: 'from');
    final safeTo = sanitizeSegment(to, fallback: 'to');
    final fileStamp = formatFileStamp(timestamp ?? DateTime.now());
    return '${safeStudentName}_${safeFrom}_${safeTo}_$fileStamp.pdf';
  }
}
