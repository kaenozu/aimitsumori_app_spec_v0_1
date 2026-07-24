library;

import 'package:flutter/material.dart';

/// Icon-only action with an explicit TalkBack label, tooltip and a minimum
/// 48×48 logical-pixel touch target.
class AccessibleIconButton extends StatelessWidget {
  const AccessibleIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final callback = enabled ? onPressed : null;
    return Semantics(
      container: true,
      button: true,
      enabled: callback != null,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: IconButton(
          tooltip: label,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: callback,
          icon: icon,
        ),
      ),
    );
  }
}

class AccessibleStatusBadge extends StatelessWidget {
  const AccessibleStatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '状態: $label',
      readOnly: true,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foregroundColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foregroundColor, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ComparisonViewMode { table, contractorCards }

class ComparisonViewModeSwitcher extends StatelessWidget {
  const ComparisonViewModeSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ComparisonViewMode value;
  final ValueChanged<ComparisonViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '比較表示形式',
      child: SegmentedButton<ComparisonViewMode>(
        key: const ValueKey('comparison-view-mode-switcher'),
        segments: const [
          ButtonSegment(
            value: ComparisonViewMode.table,
            icon: Icon(Icons.table_chart_outlined),
            label: Text('表形式'),
          ),
          ButtonSegment(
            value: ComparisonViewMode.contractorCards,
            icon: Icon(Icons.view_agenda_outlined),
            label: Text('業者別カード形式'),
          ),
        ],
        selected: {value},
        showSelectedIcon: true,
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
