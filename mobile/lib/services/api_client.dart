import 'dart:typed_data';

import '../models/api_error.dart';
import '../models/case_fee.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/user.dart';

abstract class RentApiClient {
  String? get accessToken;
  set accessToken(String? token);

  /// Dùng ở chế độ mock để giả lập mất mạng một lần hoặc chuyển tài khoản nhanh.
  bool get isMock;

  // Auth & Verification (§2)
  Future<OtpChallenge> requestOtp(String email);
  Future<AuthSession> verifyOtp(String challengeId, String code);
  Future<void> logout();
  Future<Me> getMe();
  Future<Me> submitVerification({
    required String fullName,
    required String studentCode,
    required String className,
    required String faculty,
    required String displayName,
  });
  Future<PagedResult<Me>> getAdminVerifications({
    String verification = 'pending',
    String? cursor,
  });
  Future<Me> reviewVerification(
    String userId, {
    required String decision, // approve | reject
    String? note,
    String? idempotencyKey,
  });

  // Catalog, Listings & Photos (§3)
  Future<CatalogOptions> getCatalogOptions();
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
  });
  Future<Listing> getListing(String id);
  Future<Listing> createListing(ListingInput input, {String? idempotencyKey});
  Future<Listing> updateListing(
    String id,
    Map<String, dynamic> patch,
  );
  Future<List<DateRangeValue>> getAvailability(
    String listingId, {
    required String startDate,
    required String endDate,
  });
  Future<PagedResult<BlockRange>> getBlocks(String listingId, {String? cursor});
  Future<BlockRange> createBlock(
    String listingId,
    DateRangeValue range, {
    String? idempotencyKey,
  });
  Future<void> deleteBlock(String listingId, String blockId);
  Future<Quote> quoteListing(String listingId, DateRangeValue range);
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String purpose, // listing | handover
    String? orderId,
  });
  Future<Uint8List> getPhotoBytes(String photoId);

  // Orders & Messages (§4)
  Future<Order> createOrder({
    required String listingId,
    required int listingRevision,
    required String startDate,
    required String endDate,
    String? note,
    String? idempotencyKey,
  });
  Future<PagedResult<Order>> getOrders({
    required String roleAs, // owner | renter
    String? status,
    String? cursor,
  });
  Future<Order> getOrder(String id);
  Future<Order> approveOrder(String id, {String? idempotencyKey});
  Future<Order> rejectOrder(
    String id, {
    required String reason,
    String? idempotencyKey,
  });
  Future<Order> cancelOrder(
    String id, {
    required String reason,
    String? idempotencyKey,
  });
  Future<Order> confirmPickup(
    String id, {
    required String condition,
    required List<String> accessories,
    required List<String> photoIds,
    required int cashReceived,
    String? idempotencyKey,
  });
  Future<Order> confirmReturn(
    String id, {
    required String condition,
    required List<String> accessories,
    required List<String> photoIds,
    String? idempotencyKey,
  });
  Future<Order> confirmDeposit(
    String id, {
    required int refunded,
    String? reason,
    String? idempotencyKey,
  });
  Future<PagedResult<OrderMessage>> getOrderMessages(
    String orderId, {
    String? cursor,
  });
  Future<OrderMessage> sendOrderMessage(
    String orderId, {
    required String text,
    String? idempotencyKey,
  });

  // Cases, Fees & Settlements (§5)
  Future<CaseItem> createCase({
    required String targetType,
    required String targetId,
    required String category,
    required String detail,
    String? idempotencyKey,
  });
  Future<PagedResult<CaseItem>> getCases({String? cursor});
  Future<CaseItem> getCase(String id);
  Future<PagedResult<CaseItem>> getAdminCases({
    String? status,
    String? targetType,
    String? cursor,
  });
  Future<CaseItem> resolveCase(
    String id, {
    required String resolution,
    int? refunded,
    String? handoverOutcome, // resume | cancel_unhanded
    String? idempotencyKey,
  });
  Future<FeeSummary> getMyFeeSummary();
  Future<PagedResult<FeeEntry>> getMyFeeEntries({
    String? state,
    String? cursor,
  });
  Future<PagedResult<OwnerFees>> getAdminFeeOwners({String? cursor});
  Future<PagedResult<FeeEntry>> getAdminOwnerFeeEntries(
    String ownerId, {
    String? state,
    String? cursor,
  });
  Future<Settlement> createSettlement({
    required String ownerId,
    required List<String> orderIds,
    required int receivedAmount,
    required String reference,
    String? idempotencyKey,
  });
  Future<PagedResult<Settlement>> getMySettlements({String? cursor});

  // Notifications (§6)
  Future<PagedResult<Notice>> getNotifications({String? cursor});
  Future<Notice> markNotificationRead(String id);
}
