import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/customer_service.dart';
import '../services/order_service.dart';
import '../services/payment_service.dart';
import '../services/supplier_service.dart';
import '../services/room_service.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/supplier.dart';
import '../models/room.dart';
import 'dart:ui';

// ─── SUPABASE CLIENT ──────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ─── AUTH ──────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUsernameProvider = Provider<String>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentUser?.userMetadata?['username'] as String? ??
      'unknown';
});

// ─── LOCALE ───────────────────────────────────
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('he');
  void setLocale(Locale locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

// ─── SERVICES ─────────────────────────────────
final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService(ref.watch(supabaseClientProvider));
});

final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(ref.watch(supabaseClientProvider));
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref.watch(supabaseClientProvider));
});

final supplierServiceProvider = Provider<SupplierService>((ref) {
  return SupplierService(ref.watch(supabaseClientProvider));
});

final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService(ref.watch(supabaseClientProvider));
});

// ─── DATA PROVIDERS (AsyncNotifier pattern) ───

// Customers
final customersProvider = FutureProvider.autoDispose<List<Customer>>((
  ref,
) async {
  final service = ref.watch(customerServiceProvider);
  final customers = await service.getAll();
  final debts = await service.getDebts();
  return customers
      .map((c) => c.copyWith(remainingDebt: debts[c.id] ?? 0))
      .toList();
});

// Orders
final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final service = ref.watch(orderServiceProvider);
  return service.getAll();
});

// Payments
final paymentsProvider = FutureProvider.family
    .autoDispose<List<Payment>, String?>((ref, username) async {
      final service = ref.watch(paymentServiceProvider);
      return service.getAll(username: username);
    });

// Suppliers
final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((
  ref,
) async {
  final service = ref.watch(supplierServiceProvider);
  return service.getAll();
});

// Rooms
final roomsProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  final service = ref.watch(roomServiceProvider);
  return service.getAll();
});

// Assembly orders
final assemblyOrdersProvider = FutureProvider.autoDispose<List<Order>>((
  ref,
) async {
  final service = ref.watch(orderServiceProvider);
  return service.getAssemblyOrders();
});

// Customer orders
final customerOrdersProvider = FutureProvider.family
    .autoDispose<List<Order>, String>((ref, customerId) async {
      final service = ref.watch(orderServiceProvider);
      return service.getByCustomer(customerId);
    });

// Customer orders with items (for fixing screen)
final customerOrdersWithItemsProvider = FutureProvider.family
    .autoDispose<List<Order>, String>((ref, customerId) async {
      if (customerId.isEmpty) return [];
      final service = ref.watch(orderServiceProvider);
      return service.getByCustomerWithItems(customerId);
    });

// Customer payments
final customerPaymentsProvider = FutureProvider.family
    .autoDispose<List<Payment>, String>((ref, customerId) async {
      final service = ref.watch(paymentServiceProvider);
      return service.getByCustomer(customerId);
    });

// Dashboard stats
final openOrdersCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(orderServiceProvider);
  return service.getOpenOrdersCount();
});

final upcomingAssembliesCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final service = ref.watch(orderServiceProvider);
  return service.getUpcomingAssembliesCount();
});

final totalUnpaidDebtsProvider = FutureProvider.autoDispose<double>((
  ref,
) async {
  final service = ref.watch(paymentServiceProvider);
  return service.getTotalUnpaidDebts();
});

// Selected navigation index
class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final selectedNavIndexProvider = NotifierProvider<NavIndexNotifier, int>(
  NavIndexNotifier.new,
);
