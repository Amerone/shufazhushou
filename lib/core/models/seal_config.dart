import '../../shared/constants.dart';

class SealConfig {
  final String text;
  final String fontStyle; // xiaozhuan | miuzhuan | dazhuan
  final String layout; // grid | diagonal | full_white | fine_red
  final String border; // full | broken | borrowed | none

  const SealConfig({
    this.text = kDefaultSealText,
    this.fontStyle = kDefaultSealFont,
    this.layout = kDefaultSealLayout,
    this.border = kDefaultSealBorder,
  });

  factory SealConfig.fromSettings(Map<String, String> settings) {
    return SealConfig(
      text: settings['seal_text'] ?? kDefaultSealText,
      fontStyle: settings['seal_font'] ?? kDefaultSealFont,
      layout: settings['seal_layout'] ?? kDefaultSealLayout,
      border: settings['seal_border'] ?? kDefaultSealBorder,
    );
  }

  /// 满白文 = 红底白字
  bool get isInverted => layout == 'full_white';

  /// 2×2 传统读序（右→左，上→下）
  List<List<String>> get gridLayout {
    final chars = text.split('');
    while (chars.length < 4) {
      chars.add('');
    }
    // 传统印章读序：右上→左上→右下→左下 → 显示为 [右上, 左上] [右下, 左下]
    // 即第一行第一列=第1字，第一行第二列=第2字
    // 第二行第一列=第3字，第二行第二列=第4字
    return [
      [chars[0], chars[1]],
      [chars[2], chars[3]],
    ];
  }

  SealConfig copyWith({
    String? text,
    String? fontStyle,
    String? layout,
    String? border,
  }) {
    return SealConfig(
      text: text ?? this.text,
      fontStyle: fontStyle ?? this.fontStyle,
      layout: layout ?? this.layout,
      border: border ?? this.border,
    );
  }
}
