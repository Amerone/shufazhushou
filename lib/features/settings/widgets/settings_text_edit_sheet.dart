import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsTextEditSheet extends StatefulWidget {
  const SettingsTextEditSheet({
    super.key,
    required this.title,
    required this.hintText,
    required this.initialValue,
    required this.onSave,
    required this.maxLines,
    required this.allowEmpty,
    this.maxLength,
  });

  final String title;
  final String hintText;
  final String initialValue;
  final Future<void> Function(String value) onSave;
  final int maxLines;
  final int? maxLength;
  final bool allowEmpty;

  @override
  State<SettingsTextEditSheet> createState() => _SettingsTextEditSheetState();
}

class _SettingsTextEditSheetState extends State<SettingsTextEditSheet> {
  late final TextEditingController _ctrl;
  late final String _initialValue;
  bool _saving = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _initialValue = widget.initialValue.trim();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTextChanged(String text) {
    final hasChanged = text.trim() != _initialValue;
    if (hasChanged != _hasChanged) {
      setState(() => _hasChanged = hasChanged);
    }
  }

  void _close() {
    if (_saving) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleSave() async {
    if (_saving || !_hasChanged) return;

    final value = _ctrl.text.trim();
    if (!widget.allowEmpty && value.isEmpty) {
      AppToast.showError(context, '${widget.title}\u4e0d\u80fd\u4e3a\u7a7a');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showError(context, '\u4fdd\u5b58\u5931\u8d25\uff1a$error');
      return;
    }

    if (!mounted) return;
    await InteractionFeedback.seal(context);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _buildActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final cancelButton = OutlinedButton(
          onPressed: _saving ? null : _close,
          child: const Text('取消'),
        );
        final saveButton = ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _saving || !_hasChanged ? null : _handleSave,
          child: _saving
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('\u4fdd\u5b58\u4e2d...'),
                  ],
                )
              : const Text('\u4fdd\u5b58\u4fee\u6539'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [saveButton, const SizedBox(height: 10), cancelButton],
          );
        }

        return Row(
          children: [
            Expanded(child: cancelButton),
            const SizedBox(width: 12),
            Expanded(child: saveButton),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.zero,
          child: GlassCard(
            margin: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  16,
            ),
            padding: const EdgeInsets.all(24),
            enableBlur: true,
            blurSigma: 18,
            surfaceOpacity: 0.96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: kInkSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: '关闭编辑',
                          onPressed: _saving ? null : _close,
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.62,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: kInkSecondary.withValues(alpha: 0.16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _ctrl,
                  onChanged: _handleTextChanged,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: widget.title,
                    hintText: widget.hintText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.94),
                  ),
                ),
                const SizedBox(height: 20),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
