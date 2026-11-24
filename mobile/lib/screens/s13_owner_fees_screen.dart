import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../models/case_fee.dart';
import '../state/app_providers.dart';
import '../widgets/common_ui.dart';

class OwnerFeesScreen extends ConsumerStatefulWidget {
  const OwnerFeesScreen({super.key});

  @override
  ConsumerState<OwnerFeesScreen> createState() => _OwnerFeesScreenState();
}

class _OwnerFeesScreenState extends ConsumerState<OwnerFeesScreen> {
  FeeSummary? _summary;
  List<FeeEntry> _entries = const [];
  List<Settlement> _settlements = const [];
  String? _stateFilter;
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
      final api = ref.read(apiClientProvider);
      final s = await api.getMyFeeSummary();
      final e = await api.getMyFeeEntries(state: _stateFilter);
      final st = await api.getMySettlements();
      if (!mounted) return;
      setState(() {
        _summary = s;
        _entries = e.items;
        _settlements = st.items;
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
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Phí của chủ đồ (S13)')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorStateView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tổng hợp phí duy trì', style: tt.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                'Mỗi đơn giao thành công gồm 1.000đ của chủ đồ và 1.000đ thu hộ từ người thuê.',
                                style: tt.bodySmall,
                              ),
                              const Divider(height: 20),
                              MoneyRow(
                                label: 'Tổng phí phát sinh',
                                amount: _summary!.accrued,
                              ),
                              MoneyRow(
                                label: 'Đã đối soát',
                                amount: _summary!.settled,
                              ),
                              MoneyRow(
                                label: 'Còn phải chuyển cho app',
                                amount: _summary!.outstanding,
                                emphasize: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final (code, label) in const [
                              (null, 'Tất cả'),
                              ('outstanding', 'Chưa đối soát'),
                              ('settled', 'Đã đối soát'),
                            ]) ...[
                              FilterChip(
                                label: Text(label),
                                selected: _stateFilter == code,
                                onSelected: (_) {
                                  _stateFilter = code;
                                  _load();
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Chi tiết từng đơn', style: tt.titleMedium),
                      const SizedBox(height: 8),
                      if (_entries.isEmpty)
                        const Text('Chưa có dòng phí nào.')
                      else
                        for (final e in _entries)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Đơn ${e.orderId}'),
                              subtitle: Text(
                                'Chủ đồ ${formatVnd(e.ownerFee)} + Thu hộ ${formatVnd(e.renterFee)} · ${formatTimestampVi(e.accruedAt)}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatVnd(e.total),
                                    style: tt.titleSmall,
                                  ),
                                  Text(
                                    e.state == 'settled'
                                        ? 'Đã đối soát'
                                        : 'Chờ chuyển',
                                    style: tt.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 16),
                      Text('Lịch sử chuyển gộp', style: tt.titleMedium),
                      const SizedBox(height: 8),
                      if (_settlements.isEmpty)
                        const Text('Chưa có đợt đối soát nào được xác nhận.')
                      else
                        for (final s in _settlements)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.verified_outlined),
                              title: Text(
                                'Đã nhận ${formatVnd(s.receivedAmount)} (${s.orderIds.length} đơn)',
                              ),
                              subtitle: Text(
                                'Mã tham chiếu: ${s.reference}\n${formatTimestampVi(s.confirmedAt)}',
                              ),
                              isThreeLine: true,
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
