class ApiConstants {
  static const String baseUrl = "https://admin.sbmartquick.com/api/v1";

  static const String register = "$baseUrl/auth/register";
  static const String login = "$baseUrl/auth/login";
  static const String selectStore = "$baseUrl/store/select";

  static const String syncCheck = "$baseUrl/sync-check";
  static const String categories = "$baseUrl/categories";
  static const String products = "$baseUrl/products";
  static const String createOrder = "$baseUrl/orders";
  static const String userAddresses = "$baseUrl/user/addresses";
  static const String storeUserAddress = "$baseUrl/user/addresses/store";
  static const String coupons = "$baseUrl/coupons";
  static const String validateCoupon = "$baseUrl/coupons/validate";
  static const String userWallet = "$baseUrl/user/wallet";
  static const String userWishlist = "$baseUrl/user/wishlist";
  static const String toggleWishlist = "$baseUrl/user/wishlist/toggle";
  static const String deleteAccount = "$baseUrl/user/delete-account";
  static const String registerFcmToken = "$baseUrl/user/fcm-token";
  static const String userProfile = "$baseUrl/user/profile";
  static const String updateUserProfile = "$baseUrl/user/profile/update";
  static const String sliders = "$baseUrl/sliders";

  static const String customOrderRequest = "$baseUrl/custom-order/request";
  static const String submitRating = "$baseUrl/ratings/submit";
  static const String supportTickets = "$baseUrl/support/tickets";
  static const String stores = "$baseUrl/stores";

  // Store Manager App Endpoints
  static const String managerLogin = "$baseUrl/manager/login";
  static const String managerOrders = "$baseUrl/manager/orders";
  static const String managerRiders = "$baseUrl/manager/riders";
  static const String managerUpdateOrderStatus = "$baseUrl/manager/orders/update-status";
}


