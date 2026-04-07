import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AttendanceArtworkStorageService {
  const AttendanceArtworkStorageService();

  static const _folderName = 'attendance_artworks';

  @visibleForTesting
  static Future<Directory> Function()? documentsDirectoryResolver;

  Future<Directory> resolveArtworkDirectory() async {
    final rootDirectory =
        await (documentsDirectoryResolver?.call() ??
            getApplicationDocumentsDirectory());
    final artworkDirectory = Directory(p.join(rootDirectory.path, _folderName));
    if (!await artworkDirectory.exists()) {
      await artworkDirectory.create(recursive: true);
    }
    return artworkDirectory;
  }

  Future<String> replaceArtwork({
    required String attendanceId,
    required String sourceImagePath,
    String? previousImagePath,
  }) async {
    final artworkDirectory = await resolveArtworkDirectory();

    final extension = p.extension(sourceImagePath).trim().isEmpty
        ? '.jpg'
        : p.extension(sourceImagePath);
    final fileName =
        '${attendanceId}_${DateTime.now().millisecondsSinceEpoch}$extension';
    final destinationPath = p.join(artworkDirectory.path, fileName);

    await File(sourceImagePath).copy(destinationPath);
    await _deletePreviousArtwork(
      artworkDirectoryPath: artworkDirectory.path,
      previousImagePath: previousImagePath,
      replacementPath: destinationPath,
    );

    return destinationPath;
  }

  Future<void> _deletePreviousArtwork({
    required String artworkDirectoryPath,
    required String? previousImagePath,
    required String replacementPath,
  }) async {
    final normalizedPreviousPath = previousImagePath?.trim();
    if (normalizedPreviousPath == null || normalizedPreviousPath.isEmpty) {
      return;
    }

    final previousDirectory = p.normalize(p.dirname(normalizedPreviousPath));
    final normalizedArtworkDirectory = p.normalize(artworkDirectoryPath);
    final normalizedReplacementPath = p.normalize(replacementPath);
    if (previousDirectory != normalizedArtworkDirectory ||
        p.normalize(normalizedPreviousPath) == normalizedReplacementPath) {
      return;
    }

    final previousFile = File(normalizedPreviousPath);
    if (await previousFile.exists()) {
      await previousFile.delete();
    }
  }

  Future<void> deleteArtwork(String? imagePath) async {
    final normalizedImagePath = imagePath?.trim();
    if (normalizedImagePath == null || normalizedImagePath.isEmpty) {
      return;
    }

    final artworkDirectory = await resolveArtworkDirectory();
    final normalizedArtworkDirectory = p.normalize(artworkDirectory.path);
    final normalizedImageDirectory = p.normalize(
      p.dirname(normalizedImagePath),
    );
    if (normalizedArtworkDirectory != normalizedImageDirectory) {
      return;
    }

    final imageFile = File(normalizedImagePath);
    if (await imageFile.exists()) {
      await imageFile.delete();
    }
  }

  Future<Map<String, Uint8List>> readArtworkSnapshot() async {
    final artworkDirectory = await resolveArtworkDirectory();
    final files = <String, Uint8List>{};

    await for (final entity in artworkDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      files[p.basename(entity.path)] = await entity.readAsBytes();
    }

    return files;
  }

  Future<void> restoreArtworkSnapshot(Map<String, Uint8List> files) async {
    await clearArtworkDirectory();
    if (files.isEmpty) {
      return;
    }

    final artworkDirectory = await resolveArtworkDirectory();
    for (final entry in files.entries) {
      final fileName = p.basename(entry.key);
      final destination = File(p.join(artworkDirectory.path, fileName));
      await destination.writeAsBytes(entry.value, flush: true);
    }
  }

  Future<void> copyArtworkSnapshotTo(Directory targetDirectory) async {
    if (await targetDirectory.exists()) {
      await targetDirectory.delete(recursive: true);
    }
    await targetDirectory.create(recursive: true);

    final artworkFiles = await readArtworkSnapshot();
    for (final entry in artworkFiles.entries) {
      final destination = File(p.join(targetDirectory.path, entry.key));
      await destination.writeAsBytes(entry.value, flush: true);
    }
  }

  Future<void> restoreArtworkSnapshotFrom(Directory sourceDirectory) async {
    if (!await sourceDirectory.exists()) {
      await clearArtworkDirectory();
      return;
    }

    final files = <String, Uint8List>{};
    await for (final entity in sourceDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      files[p.basename(entity.path)] = await entity.readAsBytes();
    }

    await restoreArtworkSnapshot(files);
  }

  Future<void> clearArtworkDirectory() async {
    final artworkDirectory = await resolveArtworkDirectory();
    if (!await artworkDirectory.exists()) {
      return;
    }

    await for (final entity in artworkDirectory.list(followLinks: false)) {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    }
  }
}
