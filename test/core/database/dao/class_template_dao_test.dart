import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/class_template_dao.dart';
import 'package:moyun/core/models/class_template.dart';

void main() {
  group('resolveMissingBuiltinTemplateSeeds', () {
    test('returns all builtin seeds when no template exists', () {
      final missing = resolveMissingBuiltinTemplateSeeds(
        existingTemplates: const [],
      );

      expect(missing, hasLength(builtinClassTemplateSeeds.length));
      expect(
        missing.map((item) => item.slotKey).toSet(),
        equals(builtinClassTemplateSeeds.map((item) => item.slotKey).toSet()),
      );
    });

    test('deduplicates by timeslot even if names differ', () {
      final existing = [
        const ClassTemplate(
          id: 'custom-1',
          name: '我的晚课',
          startTime: '18:00',
          endTime: '19:00',
          createdAt: 1,
        ),
        const ClassTemplate(
          id: 'custom-2',
          name: '周末自定义',
          startTime: '09:30',
          endTime: '10:30',
          createdAt: 2,
        ),
      ];

      final missing = resolveMissingBuiltinTemplateSeeds(
        existingTemplates: existing,
      );

      final missingKeys = missing.map((item) => item.slotKey).toSet();
      expect(missingKeys.contains('18:00|19:00'), isFalse);
      expect(missingKeys.contains('09:30|10:30'), isFalse);
      expect(missing, hasLength(builtinClassTemplateSeeds.length - 2));
    });
  });
}
