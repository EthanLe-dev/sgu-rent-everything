import 'dart:typed_data';

import '../core/formatters.dart';
import '../models/api_error.dart';
import '../models/case_fee.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/user.dart';
import 'api_client.dart';

class MockRentApiClient implements RentApiClient {
  MockRentApiClient() {
    _seed();
  }

  @override
  String? accessToken;

  @override
  bool get isMock => true;

  /// Cho phép test ca mất mạng một lần khi xác nhận giao/trả/đặt đơn.
  bool simulateNextNetworkError = false;

  final Map<String, Me> _users = {};
  final Map<String, String> _tokens = {}; // token -> userId
  final Map<String, String> _challenges = {}; // challengeId -> email
  final Map<String, Listing> _listings = {};
  final Map<String, List<BlockRange>> _blocks = {};
  final Map<String, Uint8List> _photos = {};
  final Map<String, String> _photoOwners = {};
  final Map<String, String> _photoPurpose = {};
  final Map<String, String?> _photoOrderId = {};
  final Map<String, Order> _orders = {};
  final Map<String, List<OrderMessage>> _messages = {};
  final Map<String, CaseItem> _cases = {};
  final Map<String, FeeEntry> _feeEntries = {};
  final Map<String, Settlement> _settlements = {};
  final Map<String, List<Notice>> _notices = {};
  final Map<String, _IdempRecord> _idempotency = {};

  int _seq = 100;
  String _nextId(String prefix) => '$prefix-${++_seq}';

  void _checkNetwork() {
    if (simulateNextNetworkError) {
      simulateNextNetworkError = false;
      throw const ApiException(
        statusCode: 0,
        code: 'network_error',
        message: 'Mất kết nối mạng (giả lập). Dữ liệu đã được giữ lại.',
      );
    }
  }

  Me _requireAuth() {
    final uid = accessToken == null ? null : _tokens[accessToken];
    if (uid == null || !_users.containsKey(uid)) {
      throw const ApiException(
        statusCode: 401,
        code: 'unauthenticated',
        message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    return _users[uid]!;
  }

  Me _requireApproved() {
    final me = _requireAuth();
    if (!me.isApproved) {
      throw const ApiException(
        statusCode: 403,
        code: 'verification_required',
        message: 'Bạn cần hoàn tất xác minh sinh viên trước khi thực hiện thao tác này.',
      );
    }
    return me;
  }

  Me _requireAdmin() {
    final me = _requireAuth();
    if (!me.isAdmin) {
      throw const ApiException(
        statusCode: 403,
        code: 'forbidden',
        message: 'Chỉ quản trị viên mới có quyền thực hiện thao tác này.',
      );
    }
    return me;
  }

  void _seed() {
    _users['user-a'] = const Me(
      id: 'user-a',
      displayName: 'Lan Trần',
      verified: true,
      email: 'lan@sgu.edu.vn',
      role: UserRole.student,
      verification: VerificationStatus.approved,
      fullName: 'Trần Ngọc Lan',
      studentCode: '3122410001',
      className: 'DCT1221',
      faculty: 'Công nghệ thông tin',
    );
    _users['user-b'] = const Me(
      id: 'user-b',
      displayName: 'Minh Nguyễn',
      verified: true,
      email: 'minh@sgu.edu.vn',
      role: UserRole.student,
      verification: VerificationStatus.approved,
      fullName: 'Nguyễn Hoàng Minh',
      studentCode: '3122410002',
      className: 'DCT1222',
      faculty: 'Công nghệ thông tin',
    );
    _users['user-c'] = const Me(
      id: 'user-c',
      displayName: 'Huy Phạm',
      verified: false,
      email: 'pending@sgu.edu.vn',
      role: UserRole.student,
      verification: VerificationStatus.pending,
      fullName: 'Phạm Gia Huy',
      studentCode: '3122410099',
      className: 'DKP1221',
      faculty: 'Kinh tế',
    );
    _users['user-d'] = const Me(
      id: 'user-d',
      displayName: 'Thảo Lê',
      verified: false,
      email: 'rejected@sgu.edu.vn',
      role: UserRole.student,
      verification: VerificationStatus.rejected,
      fullName: 'Lê Phương Thảo',
      studentCode: '3122410088',
      className: 'DNN1221',
      faculty: 'Ngoại ngữ',
      reviewNote: 'Mã sinh viên trên thẻ chưa rõ, vui lòng đối chiếu lại.',
    );
    _users['user-admin'] = const Me(
      id: 'user-admin',
      displayName: 'Quản trị viên SGU',
      verified: true,
      email: 'admin@sgu.edu.vn',
      role: UserRole.admin,
      verification: VerificationStatus.approved,
      fullName: 'Ban Quản Trị Pilot',
      studentCode: 'ADMIN01',
      className: 'QL',
      faculty: 'Phòng CTSV',
    );

    const lan = UserSummary(id: 'user-a', displayName: 'Lan Trần', verified: true);
    const minh = UserSummary(id: 'user-b', displayName: 'Minh Nguyễn', verified: true);

    _listings['item-1'] = const Listing(
      id: 'item-1',
      owner: lan,
      revision: 1,
      title: 'Máy ảnh Sony ZV-E10',
      category: 'Máy ảnh & Quay phim',
      description: 'Máy ảnh quay vlog kèm lens kit 16-50mm, pin zin và túi chống sốc.',
      condition: 'Hoạt động tốt, ngoại hình 98%',
      accessories: ['1 pin zin', 'Sạc USB-C', 'Túi đựng'],
      photoIds: ['mock-camera'],
      dailyRate: 50000,
      deposit: 300000,
      area: 'Cơ sở 2',
      pickupPoint: 'Cơ sở 2',
    );
    _listings['item-2'] = const Listing(
      id: 'item-2',
      owner: lan,
      revision: 1,
      title: 'Máy tính Casio fx-580VN X',
      category: 'Học tập & Thi cử',
      description: 'Dùng ổn định cho các môn toán cao cấp, xác suất thống kê.',
      condition: 'Mới 95%, đầy đủ nắp trượt',
      accessories: ['Nắp trượt'],
      photoIds: ['mock-calc'],
      dailyRate: 15000,
      deposit: 100000,
      area: 'Cơ sở Chính',
      pickupPoint: 'Cơ sở Chính',
    );
    _listings['item-3'] = const Listing(
      id: 'item-3',
      owner: minh,
      revision: 1,
      title: 'Áo dài trắng truyền thống (M)',
      category: 'Trang phục & Sự kiện',
      description: 'Áo dài mặc chụp kỷ yếu hoặc sự kiện trường, giặt sạch sau mỗi lượt.',
      condition: 'Mới, không ố vàng',
      accessories: ['Quần lụa trắng'],
      photoIds: ['mock-aodai'],
      dailyRate: 45000,
      deposit: 0,
      area: 'Cơ sở 1',
      pickupPoint: 'Cơ sở 1',
    );
    _listings['item-4'] = const Listing(
      id: 'item-4',
      owner: minh,
      revision: 1,
      title: 'Micro thu âm DJI Mic',
      category: 'Máy ảnh & Quay phim',
      description: 'Bộ 2 mic không dây + hộp sạc, thu âm phỏng vấn nhóm rất rõ.',
      condition: 'Pin tốt, đủ đầu lọc gió',
      accessories: ['Hộp sạc', '2 bộ phát', '1 bộ thu', 'Cáp Type-C'],
      photoIds: ['mock-mic'],
      dailyRate: 60000,
      deposit: 400000,
      area: 'Cơ sở 2',
      pickupPoint: 'Cơ sở 2',
    );

    _blocks['item-1'] = [
      const BlockRange(
        id: 'block-1',
        startDate: '2026-12-10',
        endDate: '2026-12-11',
      ),
    ];

    // Order 1: requested (Minh thuê Sony ZV-E10 của Lan - mẫu §3-4 api-contract.md)
    _orders['order-1'] = Order(
      id: 'order-1',
      listingId: 'item-1',
      title: 'Máy ảnh Sony ZV-E10',
      owner: lan,
      renter: minh,
      quote: const Quote(
        listingId: 'item-1',
        listingRevision: 1,
        startDate: '2026-11-27',
        endDate: '2026-11-28',
        days: 2,
        dailyRate: 50000,
        rent: 100000,
        deposit: 300000,
        renterFee: 1000,
        ownerFee: 1000,
        pickupTotal: 401000,
        ownerNet: 99000,
      ),
      accessories: const ['1 pin zin', 'Sạc USB-C', 'Túi đựng'],
      pickupPoint: 'Cơ sở 2',
      status: 'requested',
      overdue: false,
      pickup: const [],
      returned: const [],
      depositResult: const DepositResult(status: 'pending', claims: []),
      feeState: 'unaccrued',
      allowedActions: const [],
      createdAt: '2026-11-24T08:00:00Z',
    );
    _messages['order-1'] = [
      const OrderMessage(
        id: 'msg-1',
        orderId: 'order-1',
        senderId: 'user-b',
        text: 'Mình hẹn ở sảnh A Cơ sở 2 lúc 9h sáng nhé.',
        createdAt: '2026-11-24T08:01:00Z',
      ),
    ];

    // Order 2: approved, ready for pickup
    _orders['order-2'] = Order(
      id: 'order-2',
      listingId: 'item-2',
      title: 'Máy tính Casio fx-580VN X',
      owner: lan,
      renter: minh,
      quote: const Quote(
        listingId: 'item-2',
        listingRevision: 1,
        startDate: '2026-11-25',
        endDate: '2026-11-26',
        days: 2,
        dailyRate: 15000,
        rent: 30000,
        deposit: 100000,
        renterFee: 1000,
        ownerFee: 1000,
        pickupTotal: 131000,
        ownerNet: 29000,
      ),
      accessories: const ['Nắp trượt'],
      pickupPoint: 'Cơ sở Chính',
      status: 'approved',
      overdue: false,
      pickup: const [],
      returned: const [],
      depositResult: const DepositResult(status: 'pending', claims: []),
      feeState: 'unaccrued',
      allowedActions: const [],
      createdAt: '2026-11-24T07:00:00Z',
    );
    _messages['order-2'] = [];

    // Order 3: active & overdue (Áo dài trắng)
    _orders['order-3'] = Order(
      id: 'order-3',
      listingId: 'item-3',
      title: 'Áo dài trắng truyền thống (M)',
      owner: minh,
      renter: lan,
      quote: const Quote(
        listingId: 'item-3',
        listingRevision: 1,
        startDate: '2026-11-20',
        endDate: '2026-11-21',
        days: 2,
        dailyRate: 45000,
        rent: 90000,
        deposit: 0,
        renterFee: 1000,
        ownerFee: 1000,
        pickupTotal: 91000,
        ownerNet: 89000,
      ),
      accessories: const ['Quần lụa trắng'],
      pickupPoint: 'Cơ sở 1',
      status: 'active',
      overdue: true,
      pickup: const [
        Receipt(
          actorId: 'user-b',
          confirmedAt: '2026-11-20T01:00:00Z',
          condition: 'Mới, sạch sẽ',
          accessories: ['Quần lụa trắng'],
          photoIds: [],
          cashReceived: 91000,
        ),
        Receipt(
          actorId: 'user-a',
          confirmedAt: '2026-11-20T01:02:00Z',
          condition: 'Mới, sạch sẽ',
          accessories: ['Quần lụa trắng'],
          photoIds: [],
          cashReceived: 91000,
        ),
      ],
      returned: const [],
      depositResult: const DepositResult(status: 'pending', claims: []),
      feeState: 'outstanding',
      allowedActions: const [],
      createdAt: '2026-11-19T10:00:00Z',
    );
    _messages['order-3'] = [];
    _feeEntries['order-3'] = const FeeEntry(
      orderId: 'order-3',
      accruedAt: '2026-11-20T01:02:00Z',
      renterFee: 1000,
      ownerFee: 1000,
      total: 2000,
      state: 'outstanding',
    );

    // 5 completed orders của Lan (user-a) đang outstanding -> tổng 10.000đ (AC-06)
    for (var i = 1; i <= 5; i++) {
      final oid = 'order-fee-$i';
      _orders[oid] = Order(
        id: oid,
        listingId: 'item-1',
        title: 'Máy ảnh Sony ZV-E10 (lượt #$i)',
        owner: lan,
        renter: minh,
        quote: Quote(
          listingId: 'item-1',
          listingRevision: 1,
          startDate: '2026-11-0$i',
          endDate: '2026-11-0${i + 1}',
          days: 2,
          dailyRate: 50000,
          rent: 100000,
          deposit: 300000,
          renterFee: 1000,
          ownerFee: 1000,
          pickupTotal: 401000,
          ownerNet: 99000,
        ),
        accessories: const ['1 pin zin'],
        pickupPoint: 'Cơ sở 2',
        status: 'completed',
        overdue: false,
        pickup: const [],
        returned: const [],
        depositResult: const DepositResult(
          status: 'agreed',
          refunded: 300000,
          claims: [],
        ),
        feeState: 'outstanding',
        allowedActions: const [],
        createdAt: '2026-11-0${i}T02:00:00Z',
      );
      _feeEntries[oid] = FeeEntry(
        orderId: oid,
        accruedAt: '2026-11-0${i}T03:00:00Z',
        renterFee: 1000,
        ownerFee: 1000,
        total: 2000,
        state: 'outstanding',
      );
    }

    _notices['user-a'] = [
      const Notice(
        id: 'notice-1',
        type: 'order_requested',
        title: 'Yêu cầu thuê mới',
        body: 'Minh Nguyễn muốn thuê Máy ảnh Sony ZV-E10 (27/11 – 28/11).',
        targetType: 'order',
        targetId: 'order-1',
        createdAt: '2026-11-24T08:00:00Z',
      ),
    ];
    _notices['user-b'] = [
      const Notice(
        id: 'notice-2',
        type: 'order_approved',
        title: 'Yêu cầu đã được duyệt',
        body: 'Lan Trần đã duyệt đơn Máy tính Casio fx-580VN X.',
        targetType: 'order',
        targetId: 'order-2',
        createdAt: '2026-11-24T07:30:00Z',
      ),
    ];
  }

  bool _rangesOverlap(String s1, String e1, String s2, String e2) {
    // Tính cả hai đầu [s1, e1] và [s2, e2]
    return s1.compareTo(e2) <= 0 && s2.compareTo(e1) <= 0;
  }

  bool _hasScheduleConflict(String listingId, String start, String end,
      {String? excludeOrderId}) {
    for (final b in _blocks[listingId] ?? const <BlockRange>[]) {
      if (_rangesOverlap(start, end, b.startDate, b.endDate)) return true;
    }
    for (final o in _orders.values) {
      if (o.listingId != listingId || o.id == excludeOrderId) continue;
      if (o.status == 'approved' || o.status == 'active') {
        if (_rangesOverlap(
            start, end, o.quote.startDate, o.quote.endDate)) {
          return true;
        }
      }
    }
    return false;
  }

  Order _hydrateOrder(Order o, Me viewer) {
    final isOwner = viewer.id == o.owner.id;
    final isRenter = viewer.id == o.renter.id;
    final actions = <String>[];
    String? blockingId;

    if (isOwner) {
      for (final other in _orders.values) {
        if (other.listingId == o.listingId &&
            other.id != o.id &&
            other.status == 'active') {
          blockingId = other.id;
          break;
        }
      }
    }

    final hasOpenHandoverCase = _cases.values.any(
      (c) =>
          c.targetType == 'order' &&
          c.targetId == o.id &&
          c.category == 'handover' &&
          c.isOpen,
    );

    if (isOwner || isRenter) {
      actions.addAll(['message', 'report']);
      switch (o.status) {
        case 'requested':
          if (isOwner) actions.addAll(['approve', 'reject']);
          actions.add('cancel');
        case 'approved':
          if (o.pickup.isEmpty) {
            actions.add('cancel');
          }
          final alreadyPicked =
              o.pickup.any((r) => r.actorId == viewer.id);
          if (!alreadyPicked && !hasOpenHandoverCase) {
            actions.add('pickup');
          }
        case 'active':
          final alreadyReturned =
              o.returned.any((r) => r.actorId == viewer.id);
          if (!alreadyReturned) {
            actions.add('return');
          }
        case 'returned':
          final alreadyClaimed =
              o.depositResult.claims.any((c) => c.actorId == viewer.id);
          if (!alreadyClaimed && o.depositResult.status != 'resolved') {
            actions.add('deposit');
          }
      }
    }

    return Order(
      id: o.id,
      listingId: o.listingId,
      title: o.title,
      owner: o.owner,
      renter: o.renter,
      quote: o.quote,
      accessories: o.accessories,
      pickupPoint: o.pickupPoint,
      status: o.status,
      closeReason: o.closeReason,
      overdue: o.overdue,
      blockingOrderId: blockingId,
      pickup: o.pickup,
      returned: o.returned,
      depositResult: o.depositResult,
      feeState: o.feeState,
      allowedActions: actions,
      createdAt: o.createdAt,
    );
  }

  T _withIdempotency<T>(
    String? key,
    String scope,
    T Function() run,
  ) {
    if (key != null && key.isNotEmpty) {
      final fullKey = '$scope::$key';
      final existing = _idempotency[fullKey];
      if (existing != null) {
        return existing.result as T;
      }
      final res = run();
      _idempotency[fullKey] = _IdempRecord(res);
      return res;
    }
    return run();
  }

  @override
  Future<OtpChallenge> requestOtp(String email) async {
    _checkNetwork();
    final trimmed = email.trim().toLowerCase();
    if (!trimmed.contains('@')) {
      throw const ApiException(
        statusCode: 422,
        code: 'validation_failed',
        message: 'Email không hợp lệ.',
        fields: {'email': 'Vui lòng nhập email đúng định dạng.'},
      );
    }
    final id = _nextId('otp');
    _challenges[id] = trimmed;
    return OtpChallenge(
      challengeId: id,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
    );
  }

  @override
  Future<AuthSession> verifyOtp(String challengeId, String code) async {
    _checkNetwork();
    final email = _challenges[challengeId];
    if (email == null) {
      throw const ApiException(
        statusCode: 401,
        code: 'invalid_otp',
        message: 'Mã OTP không đúng hoặc đã hết hạn.',
      );
    }
    if (code == '000000') {
      throw const ApiException(
        statusCode: 401,
        code: 'invalid_otp',
        message: 'Mã OTP không đúng hoặc đã hết hạn.',
      );
    }
    if (code == '999999') {
      throw const ApiException(
        statusCode: 429,
        code: 'rate_limited',
        message: 'Bạn đã thử quá nhiều lần. Vui lòng chờ 45 giây.',
        retryAfterSeconds: 45,
      );
    }

    var user = _users.values.cast<Me?>().firstWhere(
          (u) => u?.email.toLowerCase() == email,
          orElse: () => null,
        );
    if (user == null) {
      final uid = _nextId('user');
      user = Me(
        id: uid,
        displayName: email.split('@').first,
        verified: false,
        email: email,
        role: UserRole.student,
        verification: VerificationStatus.unsubmitted,
      );
      _users[uid] = user;
    }

    final token = _nextId('tok');
    _tokens[token] = user.id;
    accessToken = token;
    return AuthSession(
      accessToken: token,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
      me: user,
    );
  }

  @override
  Future<void> logout() async {
    if (accessToken != null) _tokens.remove(accessToken);
    accessToken = null;
  }

  @override
  Future<Me> getMe() async => _requireAuth();

  @override
  Future<Me> submitVerification({
    required String fullName,
    required String studentCode,
    required String className,
    required String faculty,
    required String displayName,
  }) async {
    _checkNetwork();
    final me = _requireAuth();
    if (me.verification == VerificationStatus.approved) {
      throw const ApiException(
        statusCode: 409,
        code: 'invalid_state',
        message: 'Tài khoản đã được xác minh.',
      );
    }
    final updated = me.copyWith(
      fullName: fullName,
      studentCode: studentCode,
      className: className,
      faculty: faculty,
      displayName: displayName,
      verification: VerificationStatus.pending,
      reviewNote: null,
    );
    _users[me.id] = updated;
    return updated;
  }

  @override
  Future<PagedResult<Me>> getAdminVerifications({
    String verification = 'pending',
    String? cursor,
  }) async {
    _requireAdmin();
    final items = _users.values
        .where((u) => u.verification.name == verification)
        .toList();
    return PagedResult(items: items);
  }

  @override
  Future<Me> reviewVerification(
    String userId, {
    required String decision,
    String? note,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    _requireAdmin();
    final target = _users[userId];
    if (target == null) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy hồ sơ sinh viên.',
      );
    }
    if (decision == 'approve') {
      final taken = _users.values.any(
        (u) =>
            u.id != userId &&
            u.isApproved &&
            u.studentCode != null &&
            u.studentCode == target.studentCode,
      );
      if (taken) {
        throw const ApiException(
          statusCode: 409,
          code: 'student_code_taken',
          message: 'Mã sinh viên này đã gắn với một tài khoản được duyệt.',
        );
      }
      final updated = target.copyWith(
        verification: VerificationStatus.approved,
        verified: true,
        reviewNote: note,
      );
      _users[userId] = updated;
      return updated;
    } else {
      final updated = target.copyWith(
        verification: VerificationStatus.rejected,
        verified: false,
        reviewNote: (note == null || note.isEmpty)
            ? 'Hồ sơ chưa khớp thông tin thẻ sinh viên.'
            : note,
      );
      _users[userId] = updated;
      return updated;
    }
  }

  @override
  Future<CatalogOptions> getCatalogOptions() async => const CatalogOptions(
        categories: [
          'Máy ảnh & Quay phim',
          'Học tập & Thi cử',
          'Trang phục & Sự kiện',
          'Thiết bị điện tử',
          'Thể thao & Dã ngoại',
        ],
        areas: ['Cơ sở 1', 'Cơ sở 2', 'Cơ sở Chính'],
      );

  @override
  Future<PagedResult<Listing>> getListings({
    String? q,
    String? category,
    String? area,
    int? minDailyRate,
    int? maxDailyRate,
    String? startDate,
    String? endDate,
    bool? mine,
    String? cursor,
  }) async {
    final viewer = accessToken == null ? null : _users[_tokens[accessToken]];
    var items = _listings.values.toList();
    if (mine == true && viewer != null) {
      items = items.where((l) => l.owner.id == viewer.id).toList();
    }
    if (q != null && q.trim().isNotEmpty) {
      final kw = q.trim().toLowerCase();
      items = items
          .where((l) =>
              l.title.toLowerCase().contains(kw) ||
              l.description.toLowerCase().contains(kw))
          .toList();
    }
    if (category != null && category.isNotEmpty) {
      items = items.where((l) => l.category == category).toList();
    }
    if (area != null && area.isNotEmpty) {
      items = items.where((l) => l.area == area).toList();
    }
    if (minDailyRate != null) {
      items = items.where((l) => l.dailyRate >= minDailyRate).toList();
    }
    if (maxDailyRate != null) {
      items = items.where((l) => l.dailyRate <= maxDailyRate).toList();
    }
    if (startDate != null &&
        endDate != null &&
        startDate.isNotEmpty &&
        endDate.isNotEmpty) {
      items = items
          .where((l) => !_hasScheduleConflict(l.id, startDate, endDate))
          .toList();
    }
    return PagedResult(items: items);
  }

  @override
  Future<Listing> getListing(String id) async {
    final l = _listings[id];
    if (l == null) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy tin đăng.',
      );
    }
    return l;
  }

  @override
  Future<Listing> createListing(
    ListingInput input, {
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireApproved();
    return _withIdempotency(idempotencyKey, '${me.id}:createListing', () {
      final id = _nextId('item');
      final created = Listing(
        id: id,
        owner: UserSummary(
          id: me.id,
          displayName: me.displayName,
          verified: me.verified,
        ),
        revision: 1,
        title: input.title,
        category: input.category,
        description: input.description,
        condition: input.condition,
        accessories: input.accessories,
        photoIds: input.photoIds,
        dailyRate: input.dailyRate,
        deposit: input.deposit,
        area: input.area,
        pickupPoint: input.pickupPoint,
      );
      _listings[id] = created;
      return created;
    });
  }

  @override
  Future<Listing> updateListing(String id, Map<String, dynamic> patch) async {
    _checkNetwork();
    final me = _requireApproved();
    final existing = _listings[id];
    if (existing == null || existing.owner.id != me.id) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy tin đăng hoặc bạn không có quyền sửa.',
      );
    }
    final updated = Listing(
      id: existing.id,
      owner: existing.owner,
      revision: existing.revision + 1,
      title: patch['title'] as String? ?? existing.title,
      category: patch['category'] as String? ?? existing.category,
      description: patch['description'] as String? ?? existing.description,
      condition: patch['condition'] as String? ?? existing.condition,
      accessories: patch['accessories'] != null
          ? List<String>.from(patch['accessories'] as List<dynamic>)
          : existing.accessories,
      photoIds: patch['photo_ids'] != null
          ? List<String>.from(patch['photo_ids'] as List<dynamic>)
          : existing.photoIds,
      dailyRate: (patch['daily_rate'] as num?)?.toInt() ?? existing.dailyRate,
      deposit: (patch['deposit'] as num?)?.toInt() ?? existing.deposit,
      area: patch['area'] as String? ?? existing.area,
      pickupPoint: patch['pickup_point'] as String? ?? existing.pickupPoint,
    );
    _listings[id] = updated;
    return updated;
  }

  @override
  Future<List<DateRangeValue>> getAvailability(
    String listingId, {
    required String startDate,
    required String endDate,
  }) async {
    final busy = <DateRangeValue>[];
    for (final b in _blocks[listingId] ?? const <BlockRange>[]) {
      if (_rangesOverlap(startDate, endDate, b.startDate, b.endDate)) {
        busy.add(DateRangeValue(startDate: b.startDate, endDate: b.endDate));
      }
    }
    for (final o in _orders.values) {
      if (o.listingId == listingId &&
          (o.status == 'approved' || o.status == 'active')) {
        if (_rangesOverlap(
            startDate, endDate, o.quote.startDate, o.quote.endDate)) {
          busy.add(DateRangeValue(
            startDate: o.quote.startDate,
            endDate: o.quote.endDate,
          ));
        }
      }
    }
    return busy;
  }

  @override
  Future<PagedResult<BlockRange>> getBlocks(
    String listingId, {
    String? cursor,
  }) async {
    final me = _requireAuth();
    final l = _listings[listingId];
    if (l == null || l.owner.id != me.id) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy lịch khóa của tin này.',
      );
    }
    return PagedResult(items: List.of(_blocks[listingId] ?? const []));
  }

  @override
  Future<BlockRange> createBlock(
    String listingId,
    DateRangeValue range, {
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireApproved();
    final l = _listings[listingId];
    if (l == null || l.owner.id != me.id) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy tin đăng.',
      );
    }
    if (_hasScheduleConflict(listingId, range.startDate, range.endDate)) {
      throw const ApiException(
        statusCode: 409,
        code: 'schedule_conflict',
        message: 'Khoảng ngày này trùng với đơn đã duyệt hoặc lịch bận khác.',
      );
    }
    final b = BlockRange(
      id: _nextId('block'),
      startDate: range.startDate,
      endDate: range.endDate,
    );
    _blocks.putIfAbsent(listingId, () => []).add(b);
    return b;
  }

  @override
  Future<void> deleteBlock(String listingId, String blockId) async {
    final me = _requireApproved();
    final l = _listings[listingId];
    if (l == null || l.owner.id != me.id) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy tin đăng.',
      );
    }
    _blocks[listingId]?.removeWhere((b) => b.id == blockId);
  }

  @override
  Future<Quote> quoteListing(String listingId, DateRangeValue range) async {
    final l = await getListing(listingId);
    final days = calculateRentalDays(range.startDate, range.endDate);
    if (days <= 0) {
      throw const ApiException(
        statusCode: 422,
        code: 'validation_failed',
        message: 'Ngày trả phải sau hoặc bằng ngày nhận.',
      );
    }
    final rent = l.dailyRate * days;
    const fee = 1000;
    return Quote(
      listingId: l.id,
      listingRevision: l.revision,
      startDate: range.startDate,
      endDate: range.endDate,
      days: days,
      dailyRate: l.dailyRate,
      rent: rent,
      deposit: l.deposit,
      renterFee: fee,
      ownerFee: fee,
      pickupTotal: rent + fee + l.deposit,
      ownerNet: rent - fee,
    );
  }

  @override
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String purpose,
    String? orderId,
  }) async {
    _checkNetwork();
    final me = _requireAuth();
    if (mimeType != 'image/jpeg' && mimeType != 'image/png') {
      throw const ApiException(
        statusCode: 415,
        code: 'unsupported_media',
        message: 'Chỉ chấp nhận ảnh định dạng JPEG hoặc PNG.',
      );
    }
    if (bytes.length > 8 * 1024 * 1024) {
      throw const ApiException(
        statusCode: 413,
        code: 'file_too_large',
        message: 'Ảnh vượt quá giới hạn 8 MiB.',
      );
    }
    final id = _nextId('photo');
    _photos[id] = bytes;
    _photoOwners[id] = me.id;
    _photoPurpose[id] = purpose;
    _photoOrderId[id] = orderId;
    return id;
  }

  @override
  Future<Uint8List> getPhotoBytes(String photoId) async {
    final me = _requireAuth();
    final bytes = _photos[photoId];
    if (bytes == null) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy ảnh.',
      );
    }
    if (_photoPurpose[photoId] == 'handover') {
      final oid = _photoOrderId[photoId];
      final order = oid == null ? null : _orders[oid];
      final allowed = me.isAdmin ||
          _photoOwners[photoId] == me.id ||
          (order != null &&
              (order.owner.id == me.id || order.renter.id == me.id));
      if (!allowed) {
        throw const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy ảnh.',
        );
      }
    }
    return bytes;
  }

  @override
  Future<Order> createOrder({
    required String listingId,
    required int listingRevision,
    required String startDate,
    required String endDate,
    String? note,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireApproved();
    return _withIdempotency(idempotencyKey, '${me.id}:createOrder', () async {
      final l = await getListing(listingId);
      if (l.owner.id == me.id) {
        throw const ApiException(
          statusCode: 422,
          code: 'validation_failed',
          message: 'Bạn không thể tự đặt thuê món đồ của chính mình.',
        );
      }
      if (l.revision != listingRevision) {
        throw const ApiException(
          statusCode: 409,
          code: 'quote_changed',
          message: 'Thông tin hoặc giá món đồ vừa thay đổi. Vui lòng xem lại báo giá mới.',
        );
      }
      if (_hasScheduleConflict(listingId, startDate, endDate)) {
        throw const ApiException(
          statusCode: 409,
          code: 'schedule_conflict',
          message: 'Món này đã có lịch trong khoảng ngày bạn chọn.',
        );
      }
      final quote = await quoteListing(
        listingId,
        DateRangeValue(startDate: startDate, endDate: endDate),
      );
      final id = _nextId('order');
      final order = Order(
        id: id,
        listingId: l.id,
        title: l.title,
        owner: l.owner,
        renter: UserSummary(
          id: me.id,
          displayName: me.displayName,
          verified: me.verified,
        ),
        quote: quote,
        accessories: List.of(l.accessories),
        pickupPoint: l.pickupPoint,
        status: 'requested',
        overdue: false,
        pickup: const [],
        returned: const [],
        depositResult: const DepositResult(status: 'pending', claims: []),
        feeState: 'unaccrued',
        allowedActions: const [],
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      _orders[id] = order;
      _messages[id] = [
        if (note != null && note.trim().isNotEmpty)
          OrderMessage(
            id: _nextId('msg'),
            orderId: id,
            senderId: me.id,
            text: note.trim(),
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ),
      ];
      _pushNotice(
        l.owner.id,
        type: 'order_requested',
        title: 'Yêu cầu thuê mới',
        body: '${me.displayName} muốn thuê ${l.title}.',
        targetType: 'order',
        targetId: id,
      );
      return _hydrateOrder(order, me);
    });
  }

  void _pushNotice(
    String userId, {
    required String type,
    required String title,
    required String body,
    required String targetType,
    required String targetId,
  }) {
    _notices.putIfAbsent(userId, () => []).insert(
          0,
          Notice(
            id: _nextId('notice'),
            type: type,
            title: title,
            body: body,
            targetType: targetType,
            targetId: targetId,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
  }

  @override
  Future<PagedResult<Order>> getOrders({
    required String roleAs,
    String? status,
    String? cursor,
  }) async {
    final me = _requireAuth();
    var list = _orders.values.where((o) {
      if (roleAs == 'owner') return o.owner.id == me.id;
      return o.renter.id == me.id;
    }).toList();
    if (status != null && status.isNotEmpty) {
      list = list.where((o) => o.status == status).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return PagedResult(items: list.map((o) => _hydrateOrder(o, me)).toList());
  }

  @override
  Future<Order> getOrder(String id) async {
    final me = _requireAuth();
    final o = _orders[id];
    if (o == null) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy đơn thuê.',
      );
    }
    final isParty = o.owner.id == me.id || o.renter.id == me.id;
    if (!isParty && !me.isAdmin) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy đơn thuê.',
      );
    }
    return _hydrateOrder(o, me);
  }

  @override
  Future<Order> approveOrder(String id, {String? idempotencyKey}) async {
    _checkNetwork();
    final me = _requireApproved();
    return _withIdempotency(idempotencyKey, '${me.id}:approve:$id', () {
      final o = _orders[id];
      if (o == null || o.owner.id != me.id) {
        throw const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy đơn thuê.',
        );
      }
      if (o.status != 'requested') {
        throw const ApiException(
          statusCode: 409,
          code: 'invalid_state',
          message: 'Đơn không còn ở trạng thái chờ duyệt.',
        );
      }
      if (_hasScheduleConflict(
        o.listingId,
        o.quote.startDate,
        o.quote.endDate,
        excludeOrderId: o.id,
      )) {
        throw const ApiException(
          statusCode: 409,
          code: 'schedule_conflict',
          message: 'Khoảng ngày đã có đơn khác được duyệt hoặc bị khóa.',
        );
      }
      // Đóng các yêu cầu chờ trùng lịch
      for (final other in _orders.values.toList()) {
        if (other.id != o.id &&
            other.listingId == o.listingId &&
            other.status == 'requested' &&
            _rangesOverlap(o.quote.startDate, o.quote.endDate,
                other.quote.startDate, other.quote.endDate)) {
          _orders[other.id] = Order(
            id: other.id,
            listingId: other.listingId,
            title: other.title,
            owner: other.owner,
            renter: other.renter,
            quote: other.quote,
            accessories: other.accessories,
            pickupPoint: other.pickupPoint,
            status: 'rejected',
            closeReason: 'schedule_conflict',
            overdue: false,
            pickup: const [],
            returned: const [],
            depositResult: other.depositResult,
            feeState: other.feeState,
            allowedActions: const [],
            createdAt: other.createdAt,
          );
        }
      }
      final updated = Order(
        id: o.id,
        listingId: o.listingId,
        title: o.title,
        owner: o.owner,
        renter: o.renter,
        quote: o.quote,
        accessories: o.accessories,
        pickupPoint: o.pickupPoint,
        status: 'approved',
        overdue: o.overdue,
        pickup: o.pickup,
        returned: o.returned,
        depositResult: o.depositResult,
        feeState: o.feeState,
        allowedActions: const [],
        createdAt: o.createdAt,
      );
      _orders[id] = updated;
      _pushNotice(
        o.renter.id,
        type: 'order_approved',
        title: 'Đơn đã được duyệt',
        body: '${me.displayName} đã duyệt yêu cầu thuê ${o.title}.',
        targetType: 'order',
        targetId: id,
      );
      return _hydrateOrder(updated, me);
    });
  }

  @override
  Future<Order> rejectOrder(
    String id, {
    required String reason,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireApproved();
    return _withIdempotency(idempotencyKey, '${me.id}:reject:$id', () {
      final o = _orders[id];
      if (o == null || o.owner.id != me.id) {
        throw const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy đơn thuê.',
        );
      }
      if (o.status != 'requested') {
        throw const ApiException(
          statusCode: 409,
          code: 'invalid_state',
          message: 'Đơn không còn ở trạng thái chờ duyệt.',
        );
      }
      final updated = Order(
        id: o.id,
        listingId: o.listingId,
        title: o.title,
        owner: o.owner,
        renter: o.renter,
        quote: o.quote,
        accessories: o.accessories,
        pickupPoint: o.pickupPoint,
        status: 'rejected',
        closeReason: reason,
        overdue: false,
        pickup: o.pickup,
        returned: o.returned,
        depositResult: o.depositResult,
        feeState: 'unaccrued',
        allowedActions: const [],
        createdAt: o.createdAt,
      );
      _orders[id] = updated;
      return _hydrateOrder(updated, me);
    });
  }

  @override
  Future<Order> cancelOrder(
    String id, {
    required String reason,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireApproved();
    return _withIdempotency(idempotencyKey, '${me.id}:cancel:$id', () {
      final o = _orders[id];
      if (o == null || (o.owner.id != me.id && o.renter.id != me.id)) {
        throw const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy đơn thuê.',
        );
      }
      if (o.status == 'approved' && o.pickup.isNotEmpty) {
        throw const ApiException(
          statusCode: 409,
          code: 'pickup_started',
          message: 'Một bên đã xác nhận giao, không thể hủy. Vui lòng báo sự cố nếu có bất đồng.',
        );
      }
      if (o.status != 'requested' && o.status != 'approved') {
        throw const ApiException(
          statusCode: 409,
          code: 'invalid_state',
          message: 'Không thể hủy đơn ở trạng thái hiện tại.',
        );
      }
      final updated = Order(
        id: o.id,
        listingId: o.listingId,
        title: o.title,
        owner: o.owner,
        renter: o.renter,
        quote: o.quote,
        accessories: o.accessories,
        pickupPoint: o.pickupPoint,
        status: 'cancelled',
        closeReason: reason,
        overdue: false,
        pickup: o.pickup,
        returned: o.returned,
        depositResult: o.depositResult,
        feeState: 'unaccrued',
        allowedActions: const [],
        createdAt: o.createdAt,
      );
      _orders[id] = updated;
      return _hydrateOrder(updated, me);
    });
  }

  @override
  Future<Order> confirmPickup(
    String id, {
    required String condition,
    required List<String> accessories,
    required List<String> photoIds,
    required int cashReceived,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireApproved();
    return _withIdempotency(idempotencyKey, '${me.id}:pickup:$id', () {
      final o = _orders[id];
      if (o == null || (o.owner.id != me.id && o.renter.id != me.id)) {
        throw const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy đơn thuê.',
        );
      }
      if (_cases.values.any((c) =>
          c.targetType == 'order' &&
          c.targetId == id &&
          c.category == 'handover' &&
          c.isOpen)) {
        throw const ApiException(
          statusCode: 409,
          code: 'handover_disputed',
          message: 'Đơn đang có vụ việc bàn giao chờ quản trị viên xử lý.',
        );
      }
      if (_orders.values.any((other) =>
          other.id != o.id &&
          other.listingId == o.listingId &&
          other.status == 'active')) {
        throw const ApiException(
          statusCode: 409,
          code: 'item_not_returned',
          message: 'Món đồ đang ở lượt thuê trước chưa được xác nhận trả.',
        );
      }
      if (o.status != 'approved') {
        throw const ApiException(
          statusCode: 409,
          code: 'invalid_state',
          message: 'Đơn không ở trạng thái chờ giao.',
        );
      }
      if (cashReceived != o.quote.pickupTotal) {
        throw ApiException(
          statusCode: 422,
          code: 'validation_failed',
          message:
              'Số tiền thực trao phải đúng bằng tổng đã chốt (${formatVnd(o.quote.pickupTotal)}).',
        );
      }
      final existingIdx = o.pickup.indexWhere((r) => r.actorId == me.id);
      if (existingIdx >= 0) {
        final prev = o.pickup[existingIdx];
        if (prev.condition == condition &&
            prev.cashReceived == cashReceived &&
            prev.accessories.join(',') == accessories.join(',')) {
          return _hydrateOrder(o, me);
        }
        throw const ApiException(
          statusCode: 409,
          code: 'confirmation_conflict',
          message: 'Bạn đã xác nhận giao với nội dung khác trước đó.',
        );
      }
      final nextPickup = [
        ...o.pickup,
        Receipt(
          actorId: me.id,
          confirmedAt: DateTime.now().toUtc().toIso8601String(),
          condition: condition,
          accessories: accessories,
          photoIds: photoIds,
          cashReceived: cashReceived,
        ),
      ];
      final bothConfirmed = nextPickup.length >= 2;
      final updated = Order(
        id: o.id,
        listingId: o.listingId,
        title: o.title,
        owner: o.owner,
        renter: o.renter,
        quote: o.quote,
        accessories: o.accessories,
        pickupPoint: o.pickupPoint,
        status: bothConfirmed ? 'active' : 'approved',
        overdue: o.overdue,
        pickup: nextPickup,
        returned: o.returned,
        depositResult: o.depositResult,
        feeState: bothConfirmed ? 'outstanding' : 'unaccrued',
        allowedActions: const [],
        createdAt: o.createdAt,
      );
      _orders[id] = updated;
      if (bothConfirmed) {
        _feeEntries[id] = FeeEntry(
          orderId: id,
          accruedAt: DateTime.now().toUtc().toIso8601String(),
          renterFee: o.quote.renterFee,
          ownerFee: o.quote.ownerFee,
          total: o.quote.renterFee + o.quote.ownerFee,
          state: 'outstanding',
        );
      }
      return _hydrateOrder(updated, me);
    });
  }

  @override
  Future<Order> confirmReturn(
    String id, {
    required String condition,
    required List<String> accessories,
    required List<String> photoIds,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireApproved();
    return _withIdempotency(idempotencyKey, '${me.id}:return:$id', () {
      final o = _orders[id];
      if (o == null || (o.owner.id != me.id && o.renter.id != me.id)) {
        throw const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy đơn thuê.',
        );
      }
      if (o.status != 'active') {
        throw const ApiException(
          statusCode: 409,
          code: 'invalid_state',
          message: 'Đơn không ở trạng thái đang thuê.',
        );
      }
      final existingIdx = o.returned.indexWhere((r) => r.actorId == me.id);
      if (existingIdx >= 0) {
        final prev = o.returned[existingIdx];
        if (prev.condition == condition &&
            prev.accessories.join(',') == accessories.join(',')) {
          return _hydrateOrder(o, me);
        }
        throw const ApiException(
          statusCode: 409,
          code: 'confirmation_conflict',
          message: 'Bạn đã xác nhận trả với nội dung khác trước đó.',
        );
      }
      final nextReturned = [
        ...o.returned,
        Receipt(
          actorId: me.id,
          confirmedAt: DateTime.now().toUtc().toIso8601String(),
          condition: condition,
          accessories: accessories,
          photoIds: photoIds,
        ),
      ];
      final bothReturned = nextReturned.length >= 2;
      var nextStatus = bothReturned ? 'returned' : 'active';
      var nextDeposit = o.depositResult;
      if (bothReturned && o.quote.deposit == 0) {
        nextStatus = 'completed';
        nextDeposit = const DepositResult(
          status: 'agreed',
          refunded: 0,
          claims: [],
        );
      }
      final updated = Order(
        id: o.id,
        listingId: o.listingId,
        title: o.title,
        owner: o.owner,
        renter: o.renter,
        quote: o.quote,
        accessories: o.accessories,
        pickupPoint: o.pickupPoint,
        status: nextStatus,
        overdue: bothReturned ? false : o.overdue,
        pickup: o.pickup,
        returned: nextReturned,
        depositResult: nextDeposit,
        feeState: o.feeState,
        allowedActions: const [],
        createdAt: o.createdAt,
      );
      _orders[id] = updated;
      return _hydrateOrder(updated, me);
    });
  }

  @override
  Future<Order> confirmDeposit(
    String id, {
    required int refunded,
    String? reason,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireApproved();
    return _withIdempotency(idempotencyKey, '${me.id}:deposit:$id', () {
      final o = _orders[id];
      if (o == null || (o.owner.id != me.id && o.renter.id != me.id)) {
        throw const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy đơn thuê.',
        );
      }
      if (o.status != 'returned') {
        throw const ApiException(
          statusCode: 409,
          code: 'invalid_state',
          message: 'Đơn chưa ở trạng thái chờ xử lý cọc.',
        );
      }
      if (refunded < 0 || refunded > o.quote.deposit) {
        throw const ApiException(
          statusCode: 422,
          code: 'validation_failed',
          message: 'Số tiền hoàn phải nằm trong khoảng từ 0đ đến mức cọc.',
        );
      }
      if (refunded < o.quote.deposit &&
          (reason == null || reason.trim().isEmpty)) {
        throw const ApiException(
          statusCode: 422,
          code: 'validation_failed',
          message: 'Vui lòng nêu lý do khi hoàn thiếu tiền cọc.',
          fields: {'reason': 'Bắt buộc nhập lý do khấu trừ cọc.'},
        );
      }
      final claims = [...o.depositResult.claims];
      final existingIdx = claims.indexWhere((c) => c.actorId == me.id);
      if (existingIdx >= 0) {
        if (claims[existingIdx].refunded == refunded) {
          return _hydrateOrder(o, me);
        }
        throw const ApiException(
          statusCode: 409,
          code: 'confirmation_conflict',
          message: 'Bạn đã gửi kết quả hoàn cọc khác trước đó.',
        );
      }
      claims.add(DepositClaim(
        actorId: me.id,
        refunded: refunded,
        reason: reason?.trim(),
        confirmedAt: DateTime.now().toUtc().toIso8601String(),
      ));

      var nextDeposit = DepositResult(status: 'pending', claims: claims);
      var nextStatus = 'returned';
      if (claims.length >= 2) {
        if (claims[0].refunded == claims[1].refunded) {
          nextDeposit = DepositResult(
            status: 'agreed',
            refunded: claims[0].refunded,
            reason: claims[0].reason ?? claims[1].reason,
            claims: claims,
          );
          nextStatus = 'completed';
        } else {
          nextDeposit = DepositResult(status: 'disputed', claims: claims);
          final cid = _nextId('case');
          _cases[cid] = CaseItem(
            id: cid,
            targetType: 'order',
            targetId: o.id,
            reporterId: me.id,
            category: 'deposit',
            detail:
                'Hai bên khai số hoàn cọc khác nhau (${formatVnd(claims[0].refunded)} và ${formatVnd(claims[1].refunded)}).',
            status: 'open',
            createdAt: DateTime.now().toUtc().toIso8601String(),
          );
        }
      }

      final updated = Order(
        id: o.id,
        listingId: o.listingId,
        title: o.title,
        owner: o.owner,
        renter: o.renter,
        quote: o.quote,
        accessories: o.accessories,
        pickupPoint: o.pickupPoint,
        status: nextStatus,
        overdue: false,
        pickup: o.pickup,
        returned: o.returned,
        depositResult: nextDeposit,
        feeState: o.feeState,
        allowedActions: const [],
        createdAt: o.createdAt,
      );
      _orders[id] = updated;
      return _hydrateOrder(updated, me);
    });
  }

  @override
  Future<PagedResult<OrderMessage>> getOrderMessages(
    String orderId, {
    String? cursor,
  }) async {
    await getOrder(orderId);
    return PagedResult(items: List.of(_messages[orderId] ?? const []));
  }

  @override
  Future<OrderMessage> sendOrderMessage(
    String orderId, {
    required String text,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireApproved();
    await getOrder(orderId);
    return _withIdempotency(idempotencyKey, '${me.id}:msg:$orderId', () {
      final msg = OrderMessage(
        id: _nextId('msg'),
        orderId: orderId,
        senderId: me.id,
        text: text,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      _messages.putIfAbsent(orderId, () => []).add(msg);
      return msg;
    });
  }

  @override
  Future<CaseItem> createCase({
    required String targetType,
    required String targetId,
    required String category,
    required String detail,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final me = _requireAuth();
    if (targetType == 'order') {
      final o = await getOrder(targetId);
      if (category == 'handover' && (o.status != 'approved' || o.pickup.length != 1)) {
        throw const ApiException(
          statusCode: 409,
          code: 'invalid_state',
          message: 'Chỉ mở vụ việc bàn giao khi đơn đã có đúng một xác nhận giao.',
        );
      }
    }
    return _withIdempotency(idempotencyKey, '${me.id}:case', () {
      final c = CaseItem(
        id: _nextId('case'),
        targetType: targetType,
        targetId: targetId,
        reporterId: me.id,
        category: category,
        detail: detail,
        status: 'open',
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      _cases[c.id] = c;
      return c;
    });
  }

  @override
  Future<PagedResult<CaseItem>> getCases({String? cursor}) async {
    final me = _requireAuth();
    final items = _cases.values.where((c) {
      if (me.isAdmin || c.reporterId == me.id) return true;
      if (c.targetType == 'order') {
        final o = _orders[c.targetId];
        return o != null && (o.owner.id == me.id || o.renter.id == me.id);
      }
      return false;
    }).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return PagedResult(items: items);
  }

  @override
  Future<CaseItem> getCase(String id) async {
    final me = _requireAuth();
    final c = _cases[id];
    if (c == null) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy vụ việc.',
      );
    }
    final list = await getCases();
    if (!me.isAdmin && !list.items.any((x) => x.id == id)) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy vụ việc.',
      );
    }
    return c;
  }

  @override
  Future<PagedResult<CaseItem>> getAdminCases({
    String? status,
    String? targetType,
    String? cursor,
  }) async {
    _requireAdmin();
    var items = _cases.values.toList();
    if (status != null && status.isNotEmpty) {
      items = items.where((c) => c.status == status).toList();
    }
    if (targetType != null && targetType.isNotEmpty) {
      items = items.where((c) => c.targetType == targetType).toList();
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return PagedResult(items: items);
  }

  @override
  Future<CaseItem> resolveCase(
    String id, {
    required String resolution,
    int? refunded,
    String? handoverOutcome,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    _requireAdmin();
    final c = _cases[id];
    if (c == null) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy vụ việc.',
      );
    }
    if (c.targetType == 'order') {
      final o = _orders[c.targetId];
      if (o != null && c.category == 'handover') {
        if (handoverOutcome == 'cancel_unhanded') {
          _orders[o.id] = Order(
            id: o.id,
            listingId: o.listingId,
            title: o.title,
            owner: o.owner,
            renter: o.renter,
            quote: o.quote,
            accessories: o.accessories,
            pickupPoint: o.pickupPoint,
            status: 'cancelled',
            closeReason: resolution,
            overdue: false,
            pickup: o.pickup,
            returned: o.returned,
            depositResult: o.depositResult,
            feeState: 'unaccrued',
            allowedActions: const [],
            createdAt: o.createdAt,
          );
        }
      } else if (o != null && c.category == 'deposit') {
        if (refunded == null || refunded < 0 || refunded > o.quote.deposit) {
          throw const ApiException(
            statusCode: 422,
            code: 'validation_failed',
            message: 'Cần nhập số tiền hoàn cọc hợp lệ.',
          );
        }
        _orders[o.id] = Order(
          id: o.id,
          listingId: o.listingId,
          title: o.title,
          owner: o.owner,
          renter: o.renter,
          quote: o.quote,
          accessories: o.accessories,
          pickupPoint: o.pickupPoint,
          status: 'completed',
          overdue: false,
          pickup: o.pickup,
          returned: o.returned,
          depositResult: DepositResult(
            status: 'resolved',
            refunded: refunded,
            reason: resolution,
            claims: o.depositResult.claims,
          ),
          feeState: o.feeState,
          allowedActions: const [],
          createdAt: o.createdAt,
        );
      }
    }
    final resolved = CaseItem(
      id: c.id,
      targetType: c.targetType,
      targetId: c.targetId,
      reporterId: c.reporterId,
      category: c.category,
      detail: c.detail,
      status: 'resolved',
      resolution: resolution,
      createdAt: c.createdAt,
    );
    _cases[id] = resolved;
    return resolved;
  }

  FeeSummary _summaryForOwner(String ownerId) {
    var accrued = 0;
    var settled = 0;
    var outstanding = 0;
    for (final e in _feeEntries.values) {
      final o = _orders[e.orderId];
      if (o?.owner.id != ownerId) continue;
      accrued += e.total;
      if (e.state == 'settled') {
        settled += e.total;
      } else {
        outstanding += e.total;
      }
    }
    return FeeSummary(
      accrued: accrued,
      settled: settled,
      outstanding: outstanding,
    );
  }

  @override
  Future<FeeSummary> getMyFeeSummary() async {
    final me = _requireAuth();
    return _summaryForOwner(me.id);
  }

  @override
  Future<PagedResult<FeeEntry>> getMyFeeEntries({
    String? state,
    String? cursor,
  }) async {
    final me = _requireAuth();
    return getAdminOwnerFeeEntries(me.id, state: state, cursor: cursor);
  }

  @override
  Future<PagedResult<OwnerFees>> getAdminFeeOwners({String? cursor}) async {
    _requireAdmin();
    final ownerIds = <String>{};
    for (final e in _feeEntries.values) {
      final o = _orders[e.orderId];
      if (o != null) ownerIds.add(o.owner.id);
    }
    final list = ownerIds.map((oid) {
      final u = _users[oid]!;
      return OwnerFees(
        owner: UserSummary(
          id: u.id,
          displayName: u.displayName,
          verified: u.verified,
        ),
        summary: _summaryForOwner(oid),
      );
    }).toList();
    return PagedResult(items: list);
  }

  @override
  Future<PagedResult<FeeEntry>> getAdminOwnerFeeEntries(
    String ownerId, {
    String? state,
    String? cursor,
  }) async {
    final me = _requireAuth();
    if (!me.isAdmin && me.id != ownerId) {
      throw const ApiException(
        statusCode: 403,
        code: 'forbidden',
        message: 'Không có quyền xem phí của người dùng khác.',
      );
    }
    var items = _feeEntries.values.where((e) {
      final o = _orders[e.orderId];
      return o?.owner.id == ownerId;
    }).toList();
    if (state != null && state.isNotEmpty) {
      items = items.where((e) => e.state == state).toList();
    }
    return PagedResult(items: items);
  }

  @override
  Future<Settlement> createSettlement({
    required String ownerId,
    required List<String> orderIds,
    required int receivedAmount,
    required String reference,
    String? idempotencyKey,
  }) async {
    _checkNetwork();
    final admin = _requireAdmin();
    return _withIdempotency(idempotencyKey, '${admin.id}:settle:$ownerId', () {
      var expected = 0;
      for (final oid in orderIds) {
        final entry = _feeEntries[oid];
        final order = _orders[oid];
        if (entry == null || order == null || order.owner.id != ownerId) {
          throw const ApiException(
            statusCode: 422,
            code: 'validation_failed',
            message: 'Danh sách đơn đối soát không hợp lệ.',
          );
        }
        if (entry.state == 'settled') {
          throw const ApiException(
            statusCode: 409,
            code: 'already_settled',
            message: 'Một hoặc nhiều đơn đã được đối soát trước đó.',
          );
        }
        expected += entry.total;
      }
      if (expected != receivedAmount) {
        throw ApiException(
          statusCode: 422,
          code: 'validation_failed',
          message:
              'Số tiền thực nhận (${formatVnd(receivedAmount)}) không khớp tổng phí (${formatVnd(expected)}).',
        );
      }
      final sid = _nextId('stl');
      final stl = Settlement(
        id: sid,
        ownerId: ownerId,
        orderIds: List.of(orderIds),
        receivedAmount: receivedAmount,
        reference: reference,
        confirmedAt: DateTime.now().toUtc().toIso8601String(),
        confirmedBy: admin.id,
      );
      _settlements[sid] = stl;
      for (final oid in orderIds) {
        final e = _feeEntries[oid]!;
        _feeEntries[oid] = FeeEntry(
          orderId: e.orderId,
          accruedAt: e.accruedAt,
          renterFee: e.renterFee,
          ownerFee: e.ownerFee,
          total: e.total,
          state: 'settled',
          settlementId: sid,
        );
        final o = _orders[oid]!;
        _orders[oid] = Order(
          id: o.id,
          listingId: o.listingId,
          title: o.title,
          owner: o.owner,
          renter: o.renter,
          quote: o.quote,
          accessories: o.accessories,
          pickupPoint: o.pickupPoint,
          status: o.status,
          closeReason: o.closeReason,
          overdue: o.overdue,
          pickup: o.pickup,
          returned: o.returned,
          depositResult: o.depositResult,
          feeState: 'settled',
          allowedActions: const [],
          createdAt: o.createdAt,
        );
      }
      return stl;
    });
  }

  @override
  Future<PagedResult<Settlement>> getMySettlements({String? cursor}) async {
    final me = _requireAuth();
    final items =
        _settlements.values.where((s) => s.ownerId == me.id).toList();
    items.sort((a, b) => b.confirmedAt.compareTo(a.confirmedAt));
    return PagedResult(items: items);
  }

  @override
  Future<PagedResult<Notice>> getNotifications({String? cursor}) async {
    final me = _requireAuth();
    return PagedResult(items: List.of(_notices[me.id] ?? const []));
  }

  @override
  Future<Notice> markNotificationRead(String id) async {
    final me = _requireAuth();
    final list = _notices[me.id] ?? [];
    final idx = list.indexWhere((n) => n.id == id);
    if (idx < 0) {
      throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy thông báo.',
      );
    }
    final old = list[idx];
    final updated = Notice(
      id: old.id,
      type: old.type,
      title: old.title,
      body: old.body,
      targetType: old.targetType,
      targetId: old.targetId,
      readAt: old.readAt ?? DateTime.now().toUtc().toIso8601String(),
      createdAt: old.createdAt,
    );
    list[idx] = updated;
    return updated;
  }
}

class _IdempRecord {
  const _IdempRecord(this.result);
  final Object? result;
}
