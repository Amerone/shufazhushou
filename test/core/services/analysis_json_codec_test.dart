import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/analysis_result_codec.dart';

void main() {
  group('AnalysisJsonCodec', () {
    test('parses fenced json object', () {
      const raw = '''
Here is the result:
```json
{"summary":"ok","risk_alerts":["a","b"]}
```
''';

      final decoded = AnalysisJsonCodec.tryParseObject(raw);

      expect(decoded, isNotNull);
      expect(decoded!['summary'], 'ok');
    });

    test('reads alternate keys and normalized string lists', () {
      final map = <String, dynamic>{
        'summaryText': '  business summary  ',
        'recommendations': '1. first\n2. second\n- third',
      };

      expect(
        AnalysisJsonCodec.readString(
          map,
          'summary',
          alternateKey: 'summaryText',
        ),
        'business summary',
      );
      expect(AnalysisJsonCodec.readStringList(map['recommendations']), [
        'first',
        'second',
        'third',
      ]);
    });

    test('returns first non-empty line from plain text', () {
      expect(
        AnalysisJsonCodec.firstNonEmptyLine('\n\n  line one \nline two'),
        'line one',
      );
    });
  });
}
