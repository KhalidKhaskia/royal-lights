import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';

class PaymentService {
  final SupabaseClient _client;
  PaymentService(this._client);

  Future<List<Payment>> getAll({String? username}) async {
    var query = _client.from('payments').select();
    if (username != null) {
      query = query.eq('created_by', username);
    }
    final data = await query.order('date', ascending: false);
    return (data as List).map((e) => Payment.fromJson(e)).toList();
  }

  Future<List<Payment>> getByCustomer(String customerId) async {
    final data = await _client
        .from('payments')
        .select()
        .eq('customer_id', customerId)
        .order('date', ascending: false);
    return (data as List).map((e) => Payment.fromJson(e)).toList();
  }

  Future<Payment> create(Payment payment) async {
    final data = await _client
        .from('payments')
        .insert(payment.toJson())
        .select()
        .single();
    return Payment.fromJson(data);
  }

  Future<Payment> update(String id, Map<String, dynamic> updates) async {
    final data = await _client
        .from('payments')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Payment.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('payments').delete().eq('id', id);
  }

  Future<double> getTotalUnpaidDebts() async {
    final data = await _client.from('customer_debts').select('remaining_debt');
    double total = 0;
    for (final row in data) {
      final debt = (row['remaining_debt'] as num?)?.toDouble() ?? 0;
      if (debt > 0) total += debt;
    }
    return total;
  }
}
