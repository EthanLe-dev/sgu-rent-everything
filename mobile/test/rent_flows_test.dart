import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thue_do_sinh_vien/core/config.dart';
import 'package:thue_do_sinh_vien/core/formatters.dart';
import 'package:thue_do_sinh_vien/main.dart';
import 'package:thue_do_sinh_vien/models/api_error.dart';
import 'package:thue_do_sinh_vien/models/listing.dart';
import 'package:thue_do_sinh_vien/services/mock_api_client.dart';
import 'package:thue_do_sinh_vien/state/app_providers.dart';

void main() {
  group('Formatters & date calculation', () {
    test('formatVnd formats integer VND with dots', () {
      expect(formatVnd(0), '0đ');
      expect(formatVnd(1000), '1.000đ');
      expect(formatVnd(50000), '50.000đ');
      expect(formatVnd(401000), '401.000đ');
    });

    test('calculateRentalDays is inclusive of both ends', () {
      expect(calculateRentalDays('2026-11-27', '2026-11-27'), 1);
      expect(calculateRentalDays('2026-11-27', '2026-11-28'), 2);
    });
  });

  group('MockRentApiClient business & error flows', () {
    late MockRentApiClient api;

    setUp(() {
      api = MockRentApiClient();
    });

    Future<void> loginAs(String email) async {
      final ch = await api.requestOtp(email);
      await api.verifyOtp(ch.challengeId, '123456');
    }

    test('quote matches §3-4 fixture and detects quote_changed on edit',
        () async {
      await loginAs('minh@sgu.edu.vn');
      final quote = await api.quoteListing(
        'item-1',
        const DateRangeValue(startDate: '2027-03-05', endDate: '2027-03-06'),
      );
      expect(quote.days, 2);
      expect(quote.rent, 100000);
      expect(quote.renterFee, 1000);
      expect(quote.ownerFee, 1000);
      expect(quote.pickupTotal, 401000);
      expect(quote.ownerNet, 99000);

      // Owner updates listing -> revision increments -> quote_changed (409)
      await loginAs('lan@sgu.edu.vn');
      await api.updateListing('item-1', {'daily_rate': 55000});

      await loginAs('minh@sgu.edu.vn');
      await expectLater(
        () => api.createOrder(
          listingId: 'item-1',
          listingRevision: quote.listingRevision,
          startDate: '2027-03-05',
          endDate: '2027-03-06',
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'quote_changed')),
      );
    });

    test('schedule_conflict on overlapping approve and explore filtering',
        () async {
      await loginAs('minh@sgu.edu.vn');
      final o1 = await api.createOrder(
        listingId: 'item-1',
        listingRevision: 1,
        startDate: '2027-04-10',
        endDate: '2027-04-11',
      );
      final o2 = await api.createOrder(
        listingId: 'item-1',
        listingRevision: 1,
        startDate: '2027-04-11',
        endDate: '2027-04-12',
      );

      await loginAs('lan@sgu.edu.vn');
      await api.approveOrder(o1.id);

      // o2 was auto-rejected with schedule_conflict
      final o2After = await api.getOrder(o2.id);
      expect(o2After.status, 'rejected');
      expect(o2After.closeReason, 'schedule_conflict');

      // Explore with overlapping date hides item-1
      final explore = await api.getListings(
        startDate: '2027-04-10',
        endDate: '2027-04-10',
      );
      expect(explore.items.any((l) => l.id == 'item-1'), isFalse);
    });

    test('one-sided pickup, network retry idempotency, handover dispute & deposit',
        () async {
      await loginAs('minh@sgu.edu.vn');
      final order = await api.createOrder(
        listingId: 'item-1',
        listingRevision: 1,
        startDate: '2027-05-01',
        endDate: '2027-05-02',
      );
      await loginAs('lan@sgu.edu.vn');
      await api.approveOrder(order.id);

      // Lan confirms pickup -> still approved, fee unaccrued
      final afterOne = await api.confirmPickup(
        order.id,
        condition: 'Tốt',
        accessories: const ['1 pin zin'],
        photoIds: const [],
        cashReceived: 401000,
        idempotencyKey: 'k-pickup-lan',
      );
      expect(afterOne.status, 'approved');
      expect(afterOne.feeState, 'unaccrued');
      expect(afterOne.pickup.length, 1);

      // Cancel after 1 pickup -> 409 pickup_started
      await expectLater(
        () => api.cancelOrder(order.id, reason: 'Đổi ý'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'pickup_started')),
      );

      // Minh opens handover dispute -> blocks pickup
      await loginAs('minh@sgu.edu.vn');
      final handoverCase = await api.createCase(
        targetType: 'order',
        targetId: order.id,
        category: 'handover',
        detail: 'Chưa nhận được máy',
      );
      await expectLater(
        () => api.confirmPickup(
          order.id,
          condition: 'Tốt',
          accessories: const ['1 pin zin'],
          photoIds: const [],
          cashReceived: 401000,
        ),
        throwsA(
            isA<ApiException>().having((e) => e.code, 'code', 'handover_disputed')),
      );

      // Admin resolves handover case with resume
      await loginAs('admin@sgu.edu.vn');
      await api.resolveCase(
        handoverCase.id,
        resolution: 'Hai bên đã gặp lại tại Cơ sở 2',
        handoverOutcome: 'resume',
      );

      // Minh simulates network error, retries with SAME idempotencyKey
      await loginAs('minh@sgu.edu.vn');
      api.simulateNextNetworkError = true;
      await expectLater(
        () => api.confirmPickup(
          order.id,
          condition: 'Tốt',
          accessories: const ['1 pin zin'],
          photoIds: const [],
          cashReceived: 401000,
          idempotencyKey: 'k-pickup-minh',
        ),
        throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)),
      );

      final active = await api.confirmPickup(
        order.id,
        condition: 'Tốt',
        accessories: const ['1 pin zin'],
        photoIds: const [],
        cashReceived: 401000,
        idempotencyKey: 'k-pickup-minh',
      );
      expect(active.status, 'active');
      expect(active.feeState, 'outstanding');
      expect(active.pickup.length, 2);

      // Return by both
      await api.confirmReturn(
        order.id,
        condition: 'Nguyên vẹn',
        accessories: const ['1 pin zin'],
        photoIds: const [],
      );
      await loginAs('lan@sgu.edu.vn');
      final returned = await api.confirmReturn(
        order.id,
        condition: 'Nguyên vẹn',
        accessories: const ['1 pin zin'],
        photoIds: const [],
      );
      expect(returned.status, 'returned');

      // Deposit mismatch -> disputed
      await api.confirmDeposit(order.id, refunded: 250000, reason: 'Trầy nhẹ');
      await loginAs('minh@sgu.edu.vn');
      final disputed = await api.confirmDeposit(order.id, refunded: 300000);
      expect(disputed.depositResult.status, 'disputed');
    });

    test('5 outstanding orders settle to 10.000đ and out-of-role gets 404',
        () async {
      await loginAs('lan@sgu.edu.vn');
      final summary = await api.getMyFeeSummary();
      expect(summary.outstanding, 10000);

      await loginAs('admin@sgu.edu.vn');
      final stl = await api.createSettlement(
        ownerId: 'user-a',
        orderIds: const [
          'order-fee-1',
          'order-fee-2',
          'order-fee-3',
          'order-fee-4',
          'order-fee-5',
        ],
        receivedAmount: 10000,
        reference: 'VCB-TEST-01',
      );
      expect(stl.receivedAmount, 10000);

      // Pending user cannot access order-1 (out-of-role -> 404)
      await loginAs('pending@sgu.edu.vn');
      await expectLater(
        () => api.getOrder('order-1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  testWidgets('App boots to Explore with Vietnamese navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialConfigProvider.overrideWithValue(
            const AppConfig(useMock: true, apiBaseUrl: '/v1'),
          ),
        ],
        child: const ThueDoSinhVienApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thuê Đồ Sinh Viên'), findsWidgets);
    expect(find.text('Khám phá'), findsWidgets);
    expect(find.text('Đăng đồ'), findsWidgets);
    expect(find.text('Giao dịch'), findsWidgets);
    expect(find.text('Cá nhân'), findsWidgets);
    expect(find.text('Máy ảnh Sony ZV-E10'), findsOneWidget);
  });
}
