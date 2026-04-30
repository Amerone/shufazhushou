import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import 'export_summary_widgets.dart';

class ExportSwitchTile extends StatelessWidget {
  final bool value;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const ExportSwitchTile({
    super.key,
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveOnChanged = enabled ? onChanged : null;

    return Semantics(
      container: true,
      button: true,
      toggled: value,
      enabled: effectiveOnChanged != null,
      label: title,
      value: value ? '已开启' : '已关闭',
      hint: effectiveOnChanged == null
          ? subtitle
          : (value ? '轻触关闭。$subtitle' : '轻触开启。$subtitle'),
      onTap: effectiveOnChanged == null
          ? null
          : () => effectiveOnChanged(!value),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: enabled ? 0.54 : 0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
            ),
            child: InkWell(
              onTap: effectiveOnChanged == null
                  ? null
                  : () => effectiveOnChanged(!value),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final iconColor = enabled ? kPrimaryBlue : kInkSecondary;
                  final titleStyle = theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: enabled ? null : kInkSecondary,
                  );
                  final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
                    color: enabled ? null : kInkSecondary,
                  );
                  final content = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: iconColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: titleStyle),
                            const SizedBox(height: 4),
                            Text(subtitle, style: subtitleStyle),
                          ],
                        ),
                      ),
                    ],
                  );
                  final switchControl = IgnorePointer(
                    child: Switch(value: value, onChanged: effectiveOnChanged),
                  );

                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            content,
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: switchControl,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: content),
                            const SizedBox(width: 12),
                            switchControl,
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExportActionPanel extends StatelessWidget {
  final bool loading;
  final ExportActionType? activeAction;
  final VoidCallback onPreview;
  final VoidCallback onSharePdf;
  final VoidCallback onExportExcel;

  const ExportActionPanel({
    super.key,
    required this.loading,
    this.activeAction,
    required this.onPreview,
    required this.onSharePdf,
    required this.onExportExcel,
  });

  bool get _isLoading => loading || activeAction != null;

  String _labelFor(String idleLabel) {
    return idleLabel;
  }

  Widget _iconFor(IconData idleIcon) {
    return Icon(idleIcon);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            ExportMetaBadge(
              icon: Icons.preview_outlined,
              label: 'PDF 预览',
              color: kPrimaryBlue,
            ),
            ExportMetaBadge(
              icon: Icons.share_outlined,
              label: '系统分享面板',
              color: kSealRed,
            ),
            ExportMetaBadge(
              icon: Icons.table_view_outlined,
              label: '同时支持 Excel 导出',
              color: kGreen,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading) ...[
          _ExportLoadingNotice(activeAction: activeAction),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final buttonWidth = width < 420 ? width : (width - 8) / 2;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: buttonWidth,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : onPreview,
                    icon: _iconFor(Icons.preview_outlined),
                    label: Text(_labelFor('预览 PDF')),
                  ),
                ),
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : onSharePdf,
                    icon: _iconFor(Icons.share_outlined),
                    label: Text(_labelFor('分享 PDF')),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: kGreen.withValues(alpha: 0.5)),
                      foregroundColor: kGreen,
                    ),
                    onPressed: _isLoading ? null : onExportExcel,
                    icon: _iconFor(Icons.table_view_outlined),
                    label: Text(_labelFor('导出 Excel')),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

enum ExportActionType { previewPdf, sharePdf, exportExcel }

extension _ExportActionTypeCopy on ExportActionType {
  String get _noticeTitle {
    return switch (this) {
      ExportActionType.previewPdf => '准备 PDF 预览',
      ExportActionType.sharePdf => '准备 PDF 分享',
      ExportActionType.exportExcel => '正在导出 Excel',
    };
  }
}

class _ExportLoadingNotice extends StatelessWidget {
  final ExportActionType? activeAction;

  const _ExportLoadingNotice({this.activeAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = activeAction?._noticeTitle ?? '正在生成导出文件';
    const subtitle = '请稍候。';

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title。$subtitle',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kPrimaryBlue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.14)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: kPrimaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
