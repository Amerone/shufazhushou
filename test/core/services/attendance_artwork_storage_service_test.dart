import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/attendance_artwork_storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  const storage = AttendanceArtworkStorageService();

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('attendance-artwork-test');
    AttendanceArtworkStorageService.documentsDirectoryResolver = () async =>
        tempRoot;
  });

  tearDown(() async {
    AttendanceArtworkStorageService.documentsDirectoryResolver = null;
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test(
    'replaceArtwork deletes previous artwork inside managed directory',
    () async {
      final sourceA = File(p.join(tempRoot.path, 'source-a.jpg'));
      final sourceB = File(p.join(tempRoot.path, 'source-b.jpg'));
      await sourceA.writeAsBytes(const [1, 2, 3], flush: true);
      await sourceB.writeAsBytes(const [4, 5, 6], flush: true);

      final firstPath = await storage.replaceArtwork(
        attendanceId: 'attendance-1',
        sourceImagePath: sourceA.path,
      );
      final secondPath = await storage.replaceArtwork(
        attendanceId: 'attendance-1',
        sourceImagePath: sourceB.path,
        previousImagePath: firstPath,
      );

      expect(File(firstPath).existsSync(), isFalse);
      expect(File(secondPath).existsSync(), isTrue);
      expect(await File(secondPath).readAsBytes(), const [4, 5, 6]);
    },
  );

  test('restoreArtworkSnapshot replaces stale local artwork files', () async {
    final stalePath = await storage.replaceArtwork(
      attendanceId: 'attendance-2',
      sourceImagePath: await _writeSourceFile(tempRoot, 'stale.jpg', const [
        7,
        8,
        9,
      ]),
    );

    expect(File(stalePath).existsSync(), isTrue);

    await storage.restoreArtworkSnapshot({
      'restored-a.jpg': Uint8List.fromList(const [1, 1, 1]),
      'restored-b.jpg': Uint8List.fromList(const [2, 2, 2]),
    });

    final artworkDirectory = await storage.resolveArtworkDirectory();
    expect(File(stalePath).existsSync(), isFalse);
    expect(
      File(p.join(artworkDirectory.path, 'restored-a.jpg')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(artworkDirectory.path, 'restored-b.jpg')).existsSync(),
      isTrue,
    );
  });
}

Future<String> _writeSourceFile(
  Directory root,
  String name,
  List<int> bytes,
) async {
  final file = File(p.join(root.path, name));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
