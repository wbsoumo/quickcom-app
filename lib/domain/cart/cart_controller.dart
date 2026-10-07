import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String name;
  final String img;
  final double price;
  final String unit;
  final int? categoryId;
  final int? maxStock;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.img,
    required this.price,
    this.unit = "1 unit",
    this.categoryId,
    this.maxStock,
    this.quantity = 1,
  });
}

class CartController extends ChangeNotifier {
  static final CartController instance = CartController._internal();
  CartController._internal();

  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;

  int get totalItemCount {
    int count = 0;
    _items.forEach((key, item) {
      count += item.quantity;
    });
    return count;
  }

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, item) {
      total += item.price * item.quantity;
    });
    return total;
  }

  double storeDeliveryFee = 15.0;
  double freeDeliveryThreshold = 299.0;
  double minOrderAmount = 0.0;

  void updateStoreSettings({double? deliveryFee, double? freeThreshold, double? minOrder}) {
    if (deliveryFee != null) storeDeliveryFee = deliveryFee;
    if (freeThreshold != null) freeDeliveryThreshold = freeThreshold;
    if (minOrder != null) minOrderAmount = minOrder;
    notifyListeners();
  }

  double get deliveryFee => (totalAmount >= freeDeliveryThreshold || totalAmount == 0) ? 0.0 : storeDeliveryFee;
  double get handlingFee => totalAmount > 0 ? 2.0 : 0.0;
  double get mrpTotal => totalAmount * 1.15;
  double get grandTotal => totalAmount + deliveryFee + handlingFee;

  int getItemQuantity(String id) {
    return _items[id]?.quantity ?? 0;
  }

  bool addItem({
    required String id,
    required String name,
    required String img,
    required double price,
    String unit = "1 unit",
    int? categoryId,
    int? maxStock,
  }) {
    if (_items.containsKey(id)) {
      final currentQty = _items[id]!.quantity;
      final limit = maxStock ?? _items[id]!.maxStock;
      if (limit != null && currentQty >= limit) {
        return false; // Reached maximum stock limit
      }
      _items[id]!.quantity += 1;
    } else {
      if (maxStock != null && maxStock <= 0) {
        return false; // Out of stock
      }
      _items[id] = CartItem(
        id: id,
        name: name,
        img: img,
        price: price,
        unit: unit,
        categoryId: categoryId,
        maxStock: maxStock,
        quantity: 1,
      );
    }
    notifyListeners();
    return true;
  }

  void removeSingleQuantity(String id) {
    if (!_items.containsKey(id)) return;
    if (_items[id]!.quantity > 1) {
      _items[id]!.quantity -= 1;
    } else {
      _items.remove(id);
    }
    notifyListeners();
  }

  void removeItemCompletely(String id) {
    _items.remove(id);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
