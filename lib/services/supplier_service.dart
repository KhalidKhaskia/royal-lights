import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier.dart';

class SupplierService {
  final SupabaseClient _client;
  SupplierService(this._client);

  Future<List<Supplier>> getAll() async {
    final data = await _client.from('suppliers').select().order('company_name');
    return (data as List).map((e) => Supplier.fromJson(e)).toList();
  }

  Future<Supplier> create(Supplier supplier) async {
    final data = await _client
        .from('suppliers')
        .insert(supplier.toJson())
        .select()
        .single();
    return Supplier.fromJson(data);
  }

  Future<Supplier> update(String id, Map<String, dynamic> updates) async {
    final data = await _client
        .from('suppliers')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Supplier.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('suppliers').delete().eq('id', id);
  }
}
