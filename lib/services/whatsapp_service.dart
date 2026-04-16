import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsAppService {
  static final _supabase = Supabase.instance.client;

  /// Sends a WhatsApp message via the Supabase Edge Function
  static Future<bool> sendMessage(String phone, String message) async {
    try {
      final response = await _supabase.functions.invoke(
        'whatsapp-sender',
        body: {
          'to': phone,
          'message': message,
        },
      );

      return response.status == 200;
    } catch (e) {
      print('WhatsApp Error: $e');
      return false;
    }
  }

  /// Helper to send Order Ready notification to a Customer
  static Future<bool> sendCustomerOrderReady(String phone, String customerName, String orderId) {
    final text = "Hello $customerName! Great news, your order (#$orderId) is ready for pickup/delivery. Thank you for choosing Royal Lights!";
    return sendMessage(phone, text);
  }

  /// Helper to send new Purchase Order to a Supplier
  static Future<bool> sendSupplierPurchaseOrder(String phone, String supplierName, String orderId) {
    final text = "Hello $supplierName, we have a new Purchase Order (#$orderId) ready for you from Royal Lights. Please review it at your earliest convenience.";
    return sendMessage(phone, text);
  }
}
