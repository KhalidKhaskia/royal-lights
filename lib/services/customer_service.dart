import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';

class CustomerService {
  final SupabaseClient _client;
  CustomerService(this._client);

  Future<List<Customer>> getAll() async {
    final data = await _client.from('customers').select().order('card_name');
    return (data as List).map((e) => Customer.fromJson(e)).toList();
  }

  Future<Customer> getById(String id) async {
    final data = await _client.from('customers').select().eq('id', id).single();
    return Customer.fromJson(data);
  }

  Future<Map<String, double>> getDebts() async {
    final data = await _client.from('customer_debts').select();
    final Map<String, double> debts = {};
    for (final row in data) {
      debts[row['customer_id'] as String] =
          (row['remaining_debt'] as num?)?.toDouble() ?? 0;
    }
    return debts;
  }

  Future<Customer> create(Customer customer) async {
    final data = await _client
        .from('customers')
        .insert(customer.toJson())
        .select()
        .single();
    return Customer.fromJson(data);
  }

  Future<Customer> update(String id, Map<String, dynamic> updates) async {
    final data = await _client
        .from('customers')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Customer.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }
}
