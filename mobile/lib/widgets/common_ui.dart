import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/api_error.dart';

String errorMessageFrom(Object error) {
  if (error is ApiException) return error.message;
  return 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.';
}

enum StatusTone { neutral, info, success, warning, error }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.icon,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final IconData icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;

    final (bg, fg) = switch (tone) {
      StatusTone.success => (
          statusColors.successContainer,
          statusColors.onSuccessContainer,
        ),
      StatusTone.warning => (
          statusColors.warningContainer,
          statusColors.onWarningContainer,
        ),
      StatusTone.error => (cs.errorContainer, cs.onErrorContainer),
      StatusTone.info => (cs.secondaryContainer, cs.onSecondaryContainer),
      StatusTone.neutral => (cs.surfaceContainerHigh, cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class MoneyRow extends StatelessWidget {
  const MoneyRow({
    super.key,
    required this.label,
    required this.amount,
    this.emphasize = false,
    this.subtitle,
  });

  final String label;
  final int amount;
  final bool emphasize;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: emphasize
                      ? tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)
                      : tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatVnd(amount),
            style: (emphasize ? tt.titleMedium : tt.bodyMedium)?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              color: emphasize ? cs.primary : cs.onSurface,
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Đang tải dữ liệu...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(title, style: tt.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                message,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                    if (secondaryLabel != null && onSecondaryAction != null)
                      OutlinedButton(
                        onPressed: onSecondaryAction,
                        child: Text(secondaryLabel!),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.error,
    this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.error_outline,
      title: 'Không thể tải dữ liệu',
      message: errorMessageFrom(error),
      actionLabel: onRetry != null ? 'Thử lại' : null,
      onAction: onRetry,
    );
  }
}

class InlineAlertBanner extends StatelessWidget {
  const InlineAlertBanner({
    super.key,
    required this.message,
    this.tone = StatusTone.error,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final StatusTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = Theme.of(context).extension<AppStatusColors>()!;
    final (bg, fg, icon) = switch (tone) {
      StatusTone.error => (cs.errorContainer, cs.onErrorContainer, Icons.error_outline),
      StatusTone.warning => (
          sc.warningContainer,
          sc.onWarningContainer,
          Icons.warning_amber_rounded,
        ),
      StatusTone.success => (
          sc.successContainer,
          sc.onSuccessContainer,
          Icons.check_circle_outline,
        ),
      _ => (cs.secondaryContainer, cs.onSecondaryContainer, Icons.info_outline),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
