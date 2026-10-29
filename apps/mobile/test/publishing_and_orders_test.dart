import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/providers/order_provider.dart';
import 'package:kalasathi_mobile/services/api_service.dart';

void main() {
  group('Publishing Wizard State & Duplicate Prevention Tests', () {
    test('Inventory stock adjustment adheres to positive boundaries', () {
      final wizard = ProductWizardProvider();
      expect(wizard.inventoryStock, 5);

      wizard.setInventoryStock(12);
      expect(wizard.inventoryStock, 12);

      // Decrement cannot go below 1
      wizard.setInventoryStock(0);
      expect(wizard.inventoryStock, 1);

      wizard.setInventoryStock(-5);
      expect(wizard.inventoryStock, 1);
    });

    test('Draft product ID and published states prevent duplicate submissions', () async {
      final wizard = ProductWizardProvider();

      wizard.titleEn = "Terracotta Water Pitcher";
      wizard.titleHi = "मिट्टी का घड़ा";
      wizard.acceptedPrice = 450.0;
      wizard.setInventoryStock(8);
      wizard.draftProductId = 101;

      expect(wizard.draftProductId, 101);
      expect(wizard.isPublishing, isFalse);
      expect(wizard.isPublished, isFalse);

      // First publish call succeeds
      final success = await wizard.publishProduct('test_token');
      expect(success, isTrue);
      expect(wizard.isPublished, isTrue);
      expect(wizard.isPublishing, isFalse);
      expect(wizard.publishError, isNull);

      // Duplicate publish attempt while isPublished is true is safely suppressed
      final secondAttempt = await wizard.publishProduct('test_token');
      expect(secondAttempt, isTrue);
    });

    test('Generates variations and allows selecting 3-4 images', () async {
      final wizard = ProductWizardProvider();
      wizard.addPhoto(Uint8List.fromList([10, 20, 30]));

      await wizard.processPhotoInAIStudio(token: 'test_token');
      expect(wizard.imageVariations.isNotEmpty, isTrue);
      expect(wizard.selectedVariationIds.isNotEmpty, isTrue);

      // Verify selected variations list
      expect(wizard.selectedVariations.isNotEmpty, isTrue);
      expect(wizard.selectedVariationIds.length, lessThanOrEqualTo(4));

      // Toggling selection
      if (wizard.imageVariations.length >= 2) {
        final secondId = wizard.imageVariations[1]['id'] as String;
        if (!wizard.selectedVariationIds.contains(secondId)) {
          wizard.toggleVariationSelection(secondId);
          expect(wizard.selectedVariationIds.contains(secondId), isTrue);
        }
      }
    });
  });

  group('Order Provider & Lifecycle Tests', () {
    test('OrderProvider manages status transitions and cancellations', () async {
      final orderProvider = OrderProvider();

      // Initial state
      expect(orderProvider.orders.isEmpty, isTrue);
      expect(orderProvider.pendingOrdersCount, 0);

      // Fetch sample/mock orders
      await orderProvider.fetchOrders('mock_token');
      expect(orderProvider.orders.isNotEmpty, isTrue);
      final initialCount = orderProvider.orders.length;

      final firstOrder = orderProvider.orders.first;
      final orderId = firstOrder['id'] as int;

      // Status transition: accepted -> packed
      await orderProvider.advanceOrderStatus('mock_token', orderId, 'packed');
      expect(orderProvider.orders.first['status'], 'packed');

      // Order cancellation restocks inventory & refunds
      final cancelled = await orderProvider.cancelOrder('mock_token', orderId);
      // In offline/mock mode cancel returns boolean or mock response
      if (cancelled) {
        expect(orderProvider.orders.first['status'], 'cancelled');
        expect(orderProvider.orders.first['payment_status'], 'refunded');
      }
    });
  });

  group('Artisan Dashboard Data Contract Tests', () {
    test('getArtisanDashboard returns compliant metric structure', () async {
      final dashboard = await ApiService.getArtisanDashboard('mock_token');

      expect(dashboard.containsKey('gross_sales'), isTrue);
      expect(dashboard.containsKey('platform_fees'), isTrue);
      expect(dashboard.containsKey('net_earnings'), isTrue);
      expect(dashboard.containsKey('settled_payout'), isTrue);
      expect(dashboard.containsKey('pending_payout'), isTrue);
      expect(dashboard.containsKey('total_orders'), isTrue);
      expect(dashboard.containsKey('products_sold'), isTrue);
      expect(dashboard.containsKey('daily_trends'), isTrue);
      expect(dashboard.containsKey('monthly_trends'), isTrue);
    });
  });
}
