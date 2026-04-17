import 'package:flutter/material.dart';
import '../../core/models/seal_config.dart';
import '../theme.dart';

class SealStampWidget extends StatelessWidget {
  final SealConfig config;
  final double size;

  const SealStampWidget({super.key, required this.config, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final grid = config.gridLayout;
    final fontSize = size * 0.3;
    final isInverted = config.isInverted;
    final bgColor = isInverted ? kSealRed : Colors.transparent;
    final textColor = isInverted ? Colors.white : kSealRed;
    final fontWeight = config.layout == 'fine_red'
        ? FontWeight.w300
        : FontWeight.w400;

    return Transform.rotate(
      angle: -0.08,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          border: _buildBorder(),
          borderRadius: BorderRadius.circular(size * 0.06),
        ),
        padding: EdgeInsets.all(size * 0.04),
        child: _buildLayout(grid, fontSize, textColor, fontWeight),
      ),
    );
  }

  Border? _buildBorder() {
    const color = kSealRed;
    final w = size * 0.04;
    switch (config.border) {
      case 'full':
        return Border.all(color: color, width: w);
      case 'broken':
        // 各边不同宽度模拟风化
        return Border(
          top: BorderSide(color: color, width: w * 1.2),
          right: BorderSide(color: color, width: w * 0.6),
          bottom: BorderSide(color: color, width: w * 0.8),
          left: BorderSide(color: color, width: w * 1.4),
        );
      case 'borrowed':
        // 仅顶 + 右两边
        return Border(
          top: BorderSide(color: color, width: w),
          right: BorderSide(color: color, width: w),
          bottom: BorderSide.none,
          left: BorderSide.none,
        );
      case 'none':
        return null;
      default:
        return Border.all(color: color, width: w);
    }
  }

  Widget _buildLayout(
    List<List<String>> grid,
    double fontSize,
    Color textColor,
    FontWeight fontWeight,
  ) {
    final fontFamily = _resolveFontFamily();

    Widget charWidget(String ch) {
      return Text(
        ch,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          color: textColor,
          fontWeight: fontWeight,
          height: 1.1,
        ),
      );
    }

    switch (config.layout) {
      case 'diagonal':
        // 对角呼应：字距更大，呼吸感强
        return Padding(
          padding: EdgeInsets.all(size * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [charWidget(grid[0][0]), charWidget(grid[0][1])],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [charWidget(grid[1][0]), charWidget(grid[1][1])],
              ),
            ],
          ),
        );
      default:
        // grid / full_white / fine_red 均使用均分式
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [charWidget(grid[0][0]), charWidget(grid[0][1])],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [charWidget(grid[1][0]), charWidget(grid[1][1])],
            ),
          ],
        );
    }
  }

  String _resolveFontFamily() {
    // 当前全部用 MaShanZheng，预留扩展点
    switch (config.fontStyle) {
      case 'xiaozhuan':
      case 'miuzhuan':
      case 'dazhuan':
      default:
        return 'MaShanZheng';
    }
  }
}
