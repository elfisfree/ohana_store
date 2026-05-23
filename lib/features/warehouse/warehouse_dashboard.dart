// lib/features/warehouse/warehouse_dashboard.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ignore: unused_import
import 'package:intl/intl.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/order.dart';

class WarehouseDashboard extends StatefulWidget {
  const WarehouseDashboard({super.key});

  @override
  State<WarehouseDashboard> createState() => _WarehouseDashboardState();
}

class _WarehouseDashboardState extends State<WarehouseDashboard> {
  late Future<List<Order>> _warehouseOrders;

  @override
  void initState() {
    super.initState();
    _warehouseOrders = _fetchWarehouseOrders();
  }

  Future<List<Order>> _fetchWarehouseOrders() async {
    final response = await supabase
        .from('orders')
        .select()
        .inFilter('status', ['pending', 'processing'])
        .order('created_at', ascending: true);

    return (response as List).map((o) => Order.fromJson(o)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'СКЛАД: СБОРКА',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<Order>>(
        future: _warehouseOrders,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;

          if (orders.isEmpty) {
            return const Center(child: Text('Нет активных заказов для сборки'));
          }

          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _warehouseOrders = _fetchWarehouseOrders()),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  color: order.status == 'processing'
                      ? Colors.blue.shade50
                      : Colors.white,
                  child: ListTile(
                    title: Text(
                      'Заказ #${order.id.substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Статус: ${order.status == 'pending' ? 'НОВЫЙ' : 'В СБОРКЕ'}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => context.push('/warehouse/order/${order.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
