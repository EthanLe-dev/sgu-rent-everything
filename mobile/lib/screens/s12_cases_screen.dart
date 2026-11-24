import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../models/case_fee.dart';
import '../state/app_providers.dart';
import '../widgets/common_ui.dart';

class CasesScreen extends ConsumerStatefulWidget {
  const CasesScreen({super.key});

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  List<CaseItem> _items = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(apiClientProvider).getCases();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vụ việc của tôi')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorStateView(error: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.verified_outlined,
                      title: 'Chưa có vụ việc nào',
                      message:
                          'Khi bạn báo cáo tin đăng hoặc mở vụ việc từ đơn thuê, hồ sơ sẽ hiện tại đây.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final c = _items[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${c.categoryLabelVi} (${c.targetType == 'order' ? 'Đơn' : 'Tin'}: ${c.targetId})',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                      ),
                                      StatusBadge(
                                        label: c.isOpen ? 'Đang mở' : 'Đã xử lý',
                                        icon: c.isOpen
                                            ? Icons.pending_outlined
                                            : Icons.check_circle_outline,
                                        tone: c.isOpen
                                            ? StatusTone.warning
                                            : StatusTone.success,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(c.detail),
                                  if (c.resolution != null) ...[
                                    const SizedBox(height: 8),
                                    InlineAlertBanner(
                                      message: 'Kết quả: ${c.resolution}',
                                      tone: StatusTone.success,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    formatTimestampVi(c.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class ReportCaseScreen extends ConsumerStatefulWidget {
  const ReportCaseScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    this.initialCategory,
  });

  final String targetType;
  final String targetId;
  final String? initialCategory;

  @override
  ConsumerState<ReportCaseScreen> createState() => _ReportCaseScreenState();
}

class _ReportCaseScreenState extends ConsumerState<ReportCaseScreen> {
  late String _category;
  final _detailCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const _orderCategories = <(String, String)>[
    ('handover', 'Bất đồng bàn giao (chưa nhận / sai thỏa thuận)'),
    ('deposit', 'Bất đồng tiền cọc'),
    ('accessory', 'Thiếu / sai phụ kiện'),
    ('damage', 'Hư hỏng món đồ'),
    ('overdue', 'Quá hạn trả đồ'),
    ('description', 'Sai mô tả thực tế'),
    ('other', 'Lý do khác'),
  ];

  static const _listingCategories = <(String, String)>[
    ('listing_content', 'Nội dung tin đăng không phù hợp'),
    ('description', 'Sai mô tả món đồ'),
    ('other', 'Lý do khác'),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ??
        (widget.targetType == 'order' ? 'handover' : 'listing_content');
  }

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_detailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng mô tả chi tiết sự cố.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).createCase(
            targetType: widget.targetType,
            targetId: widget.targetId,
            category: _category,
            detail: _detailCtrl.text.trim(),
          );
      if (!mounted) return;
      context.go('/cases');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options =
        widget.targetType == 'order' ? _orderCategories : _listingCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo & Mở vụ việc')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            InlineAlertBanner(message: _error!, tone: StatusTone.error),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: options.any((o) => o.$1 == _category)
                ? _category
                : options.first.$1,
            decoration: const InputDecoration(labelText: 'Lý do'),
            items: [
              for (final (k, label) in options)
                DropdownMenuItem(value: k, child: Text(label)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Mô tả chi tiết',
              hintText: 'Nêu rõ thời điểm, tình trạng và yêu cầu hỗ trợ...',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Đang gửi...' : 'Gửi báo cáo'),
          ),
        ],
      ),
    );
  }
}
