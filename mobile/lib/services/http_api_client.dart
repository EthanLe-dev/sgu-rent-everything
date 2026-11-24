import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/formatters.dart';
import '../models/api_error.dart';
import '../models/case_fee.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/user.dart';
import 'api_client.dart';

class HttpRentApiClient implements RentApiClient {
  HttpRentApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  String? accessToken;

  @override
  bool get isMock => false;

  Uri _uri(String path, [Map<String, String?>? query]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final full = '$cleanBase$path';
    final filtered = <String, String>{};
    if (query != null) {
      for (final e in query.entries) {
        if (e.value != null && e.value!.isNotEmpty) {
          filtered[e.key] = e.value!;
        }
      }
    }
    return Uri.parse(full).replace(
      queryParameters: filtered.isEmpty ? null : filtered,
    );
  }

  Map<String, String> _headers({
    bool jsonContent = true,
    String? idempotencyKey,
  }) {
    final h = <String, String>{};
    if (jsonContent) h['Content-Type'] = 'application/json; charset=utf-8';
    if (accessToken != null && accessToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $accessToken';
    }
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      h['Idempotency-Key'] = idempotencyKey;
    }
    return h;
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
    String? idempotencyKey,
  }) async {
    late http.Response res;
    try {
      final uri = _uri(path, query);
      final headers = _headers(idempotencyKey: idempotencyKey);
      final encoded = body == null ? null : jsonEncode(body);
      res = switch (method) {
        'GET' => await _client.get(uri, headers: headers),
        'POST' => await _client.post(uri, headers: headers, body: encoded),
        'PUT' => await _client.put(uri, headers: headers, body: encoded),
        'PATCH' => await _client.patch(uri, headers: headers, body: encoded),
        'DELETE' => await _client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported method: $method'),
      };
    } catch (e) {
      throw const ApiException(
        statusCode: 0,
        code: 'network_error',
        message: 'Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.',
      );
    }

    if (res.statusCode == 204 || res.bodyBytes.isEmpty) {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const <String, dynamic>{};
      }
    }

    Map<String, dynamic> decoded = const {};
    try {
      final raw = jsonDecode(utf8.decode(res.bodyBytes));
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    final retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
    if (decoded.isNotEmpty) {
      throw ApiException.fromJson(
        res.statusCode,
        decoded,
        retryAfterSeconds: retryAfter,
      );
    }
    throw ApiException(
      statusCode: res.statusCode,
      code: res.statusCode == 401 ? 'unauthenticated' : 'http_error',
      message: 'Yêu cầu thất bại (mã ${res.statusCode}).',
      retryAfterSeconds: retryAfter,
    );
  }

  @override
  Future<OtpChallenge> requestOtp(String email) async {
    final json = await _sendJson('POST', '/auth/otp', body: {'email': email});
    return OtpChallenge.fromJson(json);
  }

  @override
  Future<AuthSession> verifyOtp(String challengeId, String code) async {
    final json = await _sendJson('POST', '/auth/verify', body: {
      'challenge_id': challengeId,
      'code': code,
    });
    final session = AuthSession.fromJson(json);
    accessToken = session.accessToken;
    return session;
  }

  @override
  Future<void> logout() async {
    try {
      await _sendJson('POST', '/auth/logout', body: const {});
    } finally {
      accessToken = null;
    }
  }

  @override
  Future<Me> getMe() async => Me.fromJson(await _sendJson('GET', '/me'));

  @override
  Future<Me> submitVerification({
    required String fullName,
    required String studentCode,
    required String className,
    required String faculty,
    required String displayName,
  }) async {
    final json = await _sendJson('PUT', '/me/verification', body: {
      'full_name': fullName,
      'student_code': studentCode,
      'class_name': className,
      'faculty': faculty,
      'display_name': displayName,
    });
    return Me.fromJson(json);
  }

  @override
  Future<PagedResult<Me>> getAdminVerifications({
    String verification = 'pending',
    String? cursor,
  }) async {
    final json = await _sendJson('GET', '/admin/verifications', query: {
      'verification': verification,
      'cursor': cursor,
    });
    return PagedResult.fromJson(json, Me.fromJson);
  }

  @override
  Future<Me> reviewVerification(
    String userId, {
    required String decision,
    String? note,
    String? idempotencyKey,
  }) async {
    final json = await _sendJson(
      'POST',
      '/admin/verifications/$userId/review',
      idempotencyKey: idempotencyKey ?? newUuidV4(),
      body: {
        'decision': decision,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Me.fromJson(json);
  }

  @override
  Future<CatalogOptions> getCatalogOptions() async =>
      CatalogOptions.fromJson(await _sendJson('GET', '/catalog/options'));

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
    final json = await _sendJson('GET', '/listings', query: {
      'q': q,
      'category': category,
      'area': area,
      if (minDailyRate != null) 'min_daily_rate': '$minDailyRate',
      if (maxDailyRate != null) 'max_daily_rate': '$maxDailyRate',
      'start_date': startDate,
      'end_date': endDate,
      if (mine == true) 'mine': 'true',
      'cursor': cursor,
    });
    return PagedResult.fromJson(json, Listing.fromJson);
  }

  @override
  Future<Listing> getListing(String id) async =>
      Listing.fromJson(await _sendJson('GET', '/listings/$id'));

  @override
  Future<Listing> createListing(
    ListingInput input, {
    String? idempotencyKey,
  }) async {
    final json = await _sendJson(
      'POST',
      '/listings',
      body: input.toJson(),
      idempotencyKey: idempotencyKey ?? newUuidV4(),
    );
    return Listing.fromJson(json);
  }

  @override
  Future<Listing> updateListing(String id, Map<String, dynamic> patch) async =>
      Listing.fromJson(await _sendJson('PATCH', '/listings/$id', body: patch));

  @override
  Future<List<DateRangeValue>> getAvailability(
    String listingId, {
    required String startDate,
    required String endDate,
  }) async {
    final json = await _sendJson(
      'GET',
      '/listings/$listingId/availability',
      query: {'start_date': startDate, 'end_date': endDate},
    );
    final raw = (json['unavailable'] as List<dynamic>?) ?? const [];
    return raw
        .map((e) => DateRangeValue.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PagedResult<BlockRange>> getBlocks(
    String listingId, {
    String? cursor,
  }) async {
    final json = await _sendJson(
      'GET',
      '/listings/$listingId/blocks',
      query: {'cursor': cursor},
    );
    return PagedResult.fromJson(json, BlockRange.fromJson);
  }

  @override
  Future<BlockRange> createBlock(
    String listingId,
    DateRangeValue range, {
    String? idempotencyKey,
  }) async {
    final json = await _sendJson(
      'POST',
      '/listings/$listingId/blocks',
      body: range.toJson(),
      idempotencyKey: idempotencyKey ?? newUuidV4(),
    );
    return BlockRange.fromJson(json);
  }

  @override
  Future<void> deleteBlock(String listingId, String blockId) async {
    await _sendJson('DELETE', '/listings/$listingId/blocks/$blockId');
  }

  @override
  Future<Quote> quoteListing(String listingId, DateRangeValue range) async {
    final json = await _sendJson(
      'POST',
      '/listings/$listingId/quote',
      body: range.toJson(),
    );
    return Quote.fromJson(json);
  }

  @override
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String purpose,
    String? orderId,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/photos'));
    if (accessToken != null && accessToken!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $accessToken';
    }
    req.fields['purpose'] = purpose;
    if (orderId != null) req.fields['order_id'] = orderId;
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    );
    late http.StreamedResponse streamed;
    try {
      streamed = await _client.send(req);
    } catch (_) {
      throw const ApiException(
        statusCode: 0,
        code: 'network_error',
        message: 'Mất mạng khi tải ảnh lên. Vui lòng thử lại.',
      );
    }
    final res = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded['id'] as String;
    }
    throw ApiException.fromJson(res.statusCode, decoded);
  }

  @override
  Future<Uint8List> getPhotoBytes(String photoId) async {
    final res = await _client.get(
      _uri('/photos/$photoId'),
      headers: _headers(jsonContent: false),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    throw ApiException(
      statusCode: res.statusCode,
      code: res.statusCode == 404 ? 'not_found' : 'photo_error',
      message: 'Không thể tải ảnh.',
    );
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
    final json = await _sendJson(
      'POST',
      '/orders',
      idempotencyKey: idempotencyKey ?? newUuidV4(),
      body: {
        'listing_id': listingId,
        'listing_revision': listingRevision,
        'start_date': startDate,
        'end_date': endDate,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Order.fromJson(json);
  }

  @override
  Future<PagedResult<Order>> getOrders({
    required String roleAs,
    String? status,
    String? cursor,
  }) async {
    final json = await _sendJson('GET', '/orders', query: {
      'as': roleAs,
      'status': status,
      'cursor': cursor,
    });
    return PagedResult.fromJson(json, Order.fromJson);
  }

  @override
  Future<Order> getOrder(String id) async =>
      Order.fromJson(await _sendJson('GET', '/orders/$id'));

  @override
  Future<Order> approveOrder(String id, {String? idempotencyKey}) async =>
      Order.fromJson(await _sendJson(
        'POST',
        '/orders/$id/approve',
        body: const {},
        idempotencyKey: idempotencyKey ?? newUuidV4(),
      ));

  @override
  Future<Order> rejectOrder(
    String id, {
    required String reason,
    String? idempotencyKey,
  }) async =>
      Order.fromJson(await _sendJson(
        'POST',
        '/orders/$id/reject',
        body: {'reason': reason},
        idempotencyKey: idempotencyKey ?? newUuidV4(),
      ));

  @override
  Future<Order> cancelOrder(
    String id, {
    required String reason,
    String? idempotencyKey,
  }) async =>
      Order.fromJson(await _sendJson(
        'POST',
        '/orders/$id/cancel',
        body: {'reason': reason},
        idempotencyKey: idempotencyKey ?? newUuidV4(),
      ));

  @override
  Future<Order> confirmPickup(
    String id, {
    required String condition,
    required List<String> accessories,
    required List<String> photoIds,
    required int cashReceived,
    String? idempotencyKey,
  }) async =>
      Order.fromJson(await _sendJson(
        'POST',
        '/orders/$id/pickup',
        idempotencyKey: idempotencyKey ?? newUuidV4(),
        body: {
          'condition': condition,
          'accessories': accessories,
          'photo_ids': photoIds,
          'cash_received': cashReceived,
        },
      ));

  @override
  Future<Order> confirmReturn(
    String id, {
    required String condition,
    required List<String> accessories,
    required List<String> photoIds,
    String? idempotencyKey,
  }) async =>
      Order.fromJson(await _sendJson(
        'POST',
        '/orders/$id/return',
        idempotencyKey: idempotencyKey ?? newUuidV4(),
        body: {
          'condition': condition,
          'accessories': accessories,
          'photo_ids': photoIds,
        },
      ));

  @override
  Future<Order> confirmDeposit(
    String id, {
    required int refunded,
    String? reason,
    String? idempotencyKey,
  }) async =>
      Order.fromJson(await _sendJson(
        'POST',
        '/orders/$id/deposit',
        idempotencyKey: idempotencyKey ?? newUuidV4(),
        body: {
          'refunded': refunded,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      ));

  @override
  Future<PagedResult<OrderMessage>> getOrderMessages(
    String orderId, {
    String? cursor,
  }) async {
    final json = await _sendJson(
      'GET',
      '/orders/$orderId/messages',
      query: {'cursor': cursor},
    );
    return PagedResult.fromJson(json, OrderMessage.fromJson);
  }

  @override
  Future<OrderMessage> sendOrderMessage(
    String orderId, {
    required String text,
    String? idempotencyKey,
  }) async =>
      OrderMessage.fromJson(await _sendJson(
        'POST',
        '/orders/$orderId/messages',
        body: {'text': text},
        idempotencyKey: idempotencyKey ?? newUuidV4(),
      ));

  @override
  Future<CaseItem> createCase({
    required String targetType,
    required String targetId,
    required String category,
    required String detail,
    String? idempotencyKey,
  }) async =>
      CaseItem.fromJson(await _sendJson(
        'POST',
        '/cases',
        idempotencyKey: idempotencyKey ?? newUuidV4(),
        body: {
          'target_type': targetType,
          'target_id': targetId,
          'category': category,
          'detail': detail,
        },
      ));

  @override
  Future<PagedResult<CaseItem>> getCases({String? cursor}) async {
    final json = await _sendJson('GET', '/cases', query: {'cursor': cursor});
    return PagedResult.fromJson(json, CaseItem.fromJson);
  }

  @override
  Future<CaseItem> getCase(String id) async =>
      CaseItem.fromJson(await _sendJson('GET', '/cases/$id'));

  @override
  Future<PagedResult<CaseItem>> getAdminCases({
    String? status,
    String? targetType,
    String? cursor,
  }) async {
    final json = await _sendJson('GET', '/admin/cases', query: {
      'status': status,
      'target_type': targetType,
      'cursor': cursor,
    });
    return PagedResult.fromJson(json, CaseItem.fromJson);
  }

  @override
  Future<CaseItem> resolveCase(
    String id, {
    required String resolution,
    int? refunded,
    String? handoverOutcome,
    String? idempotencyKey,
  }) async =>
      CaseItem.fromJson(await _sendJson(
        'POST',
        '/admin/cases/$id/resolve',
        idempotencyKey: idempotencyKey ?? newUuidV4(),
        body: {
          'resolution': resolution,
          if (refunded != null) 'refunded': refunded,
          if (handoverOutcome != null) 'handover_outcome': handoverOutcome,
        },
      ));

  @override
  Future<FeeSummary> getMyFeeSummary() async =>
      FeeSummary.fromJson(await _sendJson('GET', '/fees/summary'));

  @override
  Future<PagedResult<FeeEntry>> getMyFeeEntries({
    String? state,
    String? cursor,
  }) async {
    final json = await _sendJson('GET', '/fees/entries', query: {
      'state': state,
      'cursor': cursor,
    });
    return PagedResult.fromJson(json, FeeEntry.fromJson);
  }

  @override
  Future<PagedResult<OwnerFees>> getAdminFeeOwners({String? cursor}) async {
    final json = await _sendJson(
      'GET',
      '/admin/fees/owners',
      query: {'cursor': cursor},
    );
    return PagedResult.fromJson(json, OwnerFees.fromJson);
  }

  @override
  Future<PagedResult<FeeEntry>> getAdminOwnerFeeEntries(
    String ownerId, {
    String? state,
    String? cursor,
  }) async {
    final json = await _sendJson(
      'GET',
      '/admin/fees/owners/$ownerId/entries',
      query: {'state': state, 'cursor': cursor},
    );
    return PagedResult.fromJson(json, FeeEntry.fromJson);
  }

  @override
  Future<Settlement> createSettlement({
    required String ownerId,
    required List<String> orderIds,
    required int receivedAmount,
    required String reference,
    String? idempotencyKey,
  }) async =>
      Settlement.fromJson(await _sendJson(
        'POST',
        '/admin/settlements',
        idempotencyKey: idempotencyKey ?? newUuidV4(),
        body: {
          'owner_id': ownerId,
          'order_ids': orderIds,
          'received_amount': receivedAmount,
          'reference': reference,
        },
      ));

  @override
  Future<PagedResult<Settlement>> getMySettlements({String? cursor}) async {
    final json =
        await _sendJson('GET', '/settlements', query: {'cursor': cursor});
    return PagedResult.fromJson(json, Settlement.fromJson);
  }

  @override
  Future<PagedResult<Notice>> getNotifications({String? cursor}) async {
    final json =
        await _sendJson('GET', '/notifications', query: {'cursor': cursor});
    return PagedResult.fromJson(json, Notice.fromJson);
  }

  @override
  Future<Notice> markNotificationRead(String id) async =>
      Notice.fromJson(await _sendJson('PUT', '/notifications/$id/read', body: const {}));
}
