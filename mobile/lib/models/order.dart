import 'listing.dart';
import 'user.dart';

class Receipt {
  const Receipt({
    required this.actorId,
    required this.confirmedAt,
    required this.condition,
    required this.accessories,
    required this.photoIds,
    this.cashReceived,
  });

  final String actorId;
  final String confirmedAt;
  final String condition;
  final List<String> accessories;
  final List<String> photoIds;
  final int? cashReceived;

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        actorId: json['actor_id'] as String,
        confirmedAt: json['confirmed_at'] as String,
        condition: json['condition'] as String,
        accessories: List<String>.from(json['accessories'] as List<dynamic>),
        photoIds: List<String>.from(json['photo_ids'] as List<dynamic>),
        cashReceived: (json['cash_received'] as num?)?.toInt(),
      );
}

class DepositClaim {
  const DepositClaim({
    required this.actorId,
    required this.refunded,
    this.reason,
    required this.confirmedAt,
  });

  final String actorId;
  final int refunded;
  final String? reason;
  final String confirmedAt;

  factory DepositClaim.fromJson(Map<String, dynamic> json) => DepositClaim(
        actorId: json['actor_id'] as String,
        refunded: (json['refunded'] as num).toInt(),
        reason: json['reason'] as String?,
        confirmedAt: json['confirmed_at'] as String,
      );
}

class DepositResult {
  const DepositResult({
    required this.status,
    this.refunded,
    this.reason,
    required this.claims,
  });

  final String status; // pending, disputed, agreed, resolved
  final int? refunded;
  final String? reason;
  final List<DepositClaim> claims;

  String get labelVi => switch (status) {
        'agreed' => 'Đã thống nhất',
        'resolved' => 'Quản trị viên đã chốt',
        'disputed' => 'Đang tranh chấp cọc',
        _ => 'Chờ xác nhận hoàn cọc',
      };

  factory DepositResult.fromJson(Map<String, dynamic> json) => DepositResult(
        status: json['status'] as String,
        refunded: (json['refunded'] as num?)?.toInt(),
        reason: json['reason'] as String?,
        claims: ((json['claims'] as List<dynamic>?) ?? const [])
            .map((e) => DepositClaim.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Order {
  const Order({
    required this.id,
    required this.listingId,
    required this.title,
    required this.owner,
    required this.renter,
    required this.quote,
    required this.accessories,
    required this.pickupPoint,
    required this.status,
    this.closeReason,
    required this.overdue,
    this.blockingOrderId,
    required this.pickup,
    required this.returned,
    required this.depositResult,
    required this.feeState,
    required this.allowedActions,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String title;
  final UserSummary owner;
  final UserSummary renter;
  final Quote quote;
  final List<String> accessories;
  final String pickupPoint;
  final String status; // requested, approved, active, returned, completed, cancelled, rejected, expired
  final String? closeReason;
  final bool overdue;
  final String? blockingOrderId;
  final List<Receipt> pickup;
  final List<Receipt> returned;
  final DepositResult depositResult;
  final String feeState; // unaccrued, outstanding, settled
  final List<String> allowedActions;
  final String createdAt;

  bool can(String action) => allowedActions.contains(action);

  String get displayStatusVi {
    if (status == 'approved' && pickup.length == 1) {
      return 'Một bên đã xác nhận giao';
    }
    if (status == 'approved') return 'Đã duyệt · Chờ giao';
    if (status == 'active' && returned.length == 1) {
      return 'Một bên đã xác nhận trả';
    }
    return switch (status) {
      'requested' => 'Chờ chủ đồ trả lời',
      'active' => overdue ? 'Đang thuê · Quá hạn' : 'Đang thuê',
      'returned' => 'Đã trả · Chờ xử lý cọc',
      'completed' => 'Hoàn tất',
      'cancelled' => 'Đã hủy',
      'rejected' => 'Bị từ chối',
      'expired' => 'Hết hạn',
      _ => status,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        listingId: json['listing_id'] as String,
        title: json['title'] as String,
        owner: UserSummary.fromJson(json['owner'] as Map<String, dynamic>),
        renter: UserSummary.fromJson(json['renter'] as Map<String, dynamic>),
        quote: Quote.fromJson(json['quote'] as Map<String, dynamic>),
        accessories: List<String>.from(json['accessories'] as List<dynamic>),
        pickupPoint: json['pickup_point'] as String,
        status: json['status'] as String,
        closeReason: json['close_reason'] as String?,
        overdue: json['overdue'] as bool? ?? false,
        blockingOrderId: json['blocking_order_id'] as String?,
        pickup: ((json['pickup'] as List<dynamic>?) ?? const [])
            .map((e) => Receipt.fromJson(e as Map<String, dynamic>))
            .toList(),
        returned: ((json['returned'] as List<dynamic>?) ?? const [])
            .map((e) => Receipt.fromJson(e as Map<String, dynamic>))
            .toList(),
        depositResult: DepositResult.fromJson(
            json['deposit_result'] as Map<String, dynamic>),
        feeState: json['fee_state'] as String,
        allowedActions:
            List<String>.from(json['allowed_actions'] as List<dynamic>),
        createdAt: json['created_at'] as String,
      );
}

class OrderMessage {
  const OrderMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isPending = false,
    this.isFailed = false,
  });

  final String id;
  final String orderId;
  final String senderId;
  final String text;
  final String createdAt;
  final bool isPending;
  final bool isFailed;

  factory OrderMessage.fromJson(Map<String, dynamic> json) => OrderMessage(
        id: json['id'] as String,
        orderId: json['order_id'] as String,
        senderId: json['sender_id'] as String,
        text: json['text'] as String,
        createdAt: json['created_at'] as String,
      );
}
