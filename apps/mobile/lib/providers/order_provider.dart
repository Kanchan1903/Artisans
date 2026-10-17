import 'package:flutter/material.dart';
import 'package:kalasathi_mobile/services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;

  int get pendingOrdersCount =>
      _orders.where((o) => o['status'] == 'pending' || o['status'] == 'accepted').length;

  Future<void> fetchOrders(String token) async {
    _isLoading = true;
    notifyListeners();

    _orders = await ApiService.getMyOrders(token);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> advanceOrderStatus(String token, int orderId, String nextStatus) async {
    final success = await ApiService.updateOrderStatus(
      token: token,
      orderId: orderId,
      status: nextStatus,
    );

    if (success) {
      final index = _orders.indexWhere((o) => o['id'] == orderId);
      if (index != -1) {
        _orders[index]['status'] = nextStatus;
        notifyListeners();
      }
    }
  }

  Future<bool> cancelOrder(String token, int orderId) async {
    final success = await ApiService.cancelOrder(
      token: token,
      orderId: orderId,
    );
    if (success) {
      final index = _orders.indexWhere((o) => o['id'] == orderId);
      if (index != -1) {
        _orders[index]['status'] = 'cancelled';
        _orders[index]['payment_status'] = 'refunded';
        notifyListeners();
      }
    }
    return success;
  }
}
