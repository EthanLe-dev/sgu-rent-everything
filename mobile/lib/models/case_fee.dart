import 'user.dart';

class CaseItem {
  const CaseItem({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reporterId,
    required this.category,
    required this.detail,
    required this.status,
    this.resolution,
    required this.createdAt,
  });

  final String id;
  final String targetType; // listing, order
  final String targetId;
  final String reporterId;
  final String category;
  final String detail;
  final String status; // open, resolved
  final String? resolution;
  final String createdAt;

  bool get isOpen => status == 'open';

  String get categoryLabelVi => switch (category) {
        'listing_content' => 'Nội dung tin đăng',
        'description' => 'Sai mô tả',
        'accessory' => 'Thiếu/sai phụ kiện',
        'damage' => 'Hư hỏng món đồ',
        'overdue' => 'Quá hạn trả đồ',
        'deposit' => 'Bất đồng tiền cọc',
        'handover' => 'Bất đồng bàn giao',
        _ => 'Lý do khác',
      };

  factory CaseItem.fromJson(Map<String, dynamic> json) => CaseItem(
        id: json['id'] as String,
        targetType: json['target_type'] as String,
        targetId: json['target_id'] as String,
        reporterId: json['reporter_id'] as String,
        category: json['category'] as String,
        detail: json['detail'] as String,
        status: json['status'] as String,
        resolution: json['resolution'] as String?,
        createdAt: json['created_at'] as String,
      );
}

class FeeSummary {
  const FeeSummary({
    required this.accrued,
    required this.settled,
    required this.outstanding,
  });

  final int accrued;
  final int settled;
  final int outstanding;

  factory FeeSummary.fromJson(Map<String, dynamic> json) => FeeSummary(
        accrued: (json['accrued'] as num).toInt(),
        settled: (json['settled'] as num).toInt(),
        outstanding: (json['outstanding'] as num).toInt(),
      );
}

class FeeEntry {
  const FeeEntry({
    required this.orderId,
    required this.accruedAt,
    required this.renterFee,
    required this.ownerFee,
    required this.total,
    required this.state,
    this.settlementId,
  });

  final String orderId;
  final String accruedAt;
  final int renterFee;
  final int ownerFee;
  final int total;
  final String state; // outstanding, settled
  final String? settlementId;

  factory FeeEntry.fromJson(Map<String, dynamic> json) => FeeEntry(
        orderId: json['order_id'] as String,
        accruedAt: json['accrued_at'] as String,
        renterFee: (json['renter_fee'] as num).toInt(),
        ownerFee: (json['owner_fee'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        state: json['state'] as String,
        settlementId: json['settlement_id'] as String?,
      );
}

class OwnerFees {
  const OwnerFees({required this.owner, required this.summary});

  final UserSummary owner;
  final FeeSummary summary;

  factory OwnerFees.fromJson(Map<String, dynamic> json) => OwnerFees(
        owner: UserSummary.fromJson(json['owner'] as Map<String, dynamic>),
        summary: FeeSummary.fromJson(json['summary'] as Map<String, dynamic>),
      );
}

class Settlement {
  const Settlement({
    required this.id,
    required this.ownerId,
    required this.orderIds,
    required this.receivedAmount,
    required this.reference,
    required this.confirmedAt,
    required this.confirmedBy,
  });

  final String id;
  final String ownerId;
  final List<String> orderIds;
  final int receivedAmount;
  final String reference;
  final String confirmedAt;
  final String confirmedBy;

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        orderIds: List<String>.from(json['order_ids'] as List<dynamic>),
        receivedAmount: (json['received_amount'] as num).toInt(),
        reference: json['reference'] as String,
        confirmedAt: json['confirmed_at'] as String,
        confirmedBy: json['confirmed_by'] as String,
      );
}

class Notice {
  const Notice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String targetType; // order, case
  final String targetId;
  final String? readAt;
  final String createdAt;

  bool get isUnread => readAt == null;

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        targetType: json['target_type'] as String,
        targetId: json['target_id'] as String,
        readAt: json['read_at'] as String?,
        createdAt: json['created_at'] as String,
      );
}
