// lib/features/warehouse/warehouse_dashboard.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  void _refreshOrders() {
    setState(() {
      _warehouseOrders = _fetchWarehouseOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'ТЕРМИНАЛ СБОРОК',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить список',
            onPressed: _refreshOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<Order>>(
        future: _warehouseOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка сети: ${snapshot.error}'));
          }

          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Все заказы собраны!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refreshOrders,
                    child: const Text('ПРОВЕРИТЬ НОВЫЕ'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final bool isProcessing = order.status == 'processing';
                final String formattedDate = DateFormat(
                  'dd.MM.yyyy, HH:mm',
                ).format(order.createdAt.toLocal());

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isProcessing ? Colors.blue.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isProcessing
                          ? Colors.blue.shade300
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () async {
                      final bool? result = await context.push<bool>(
                        '/warehouse/order/${order.id}',
                      );
                      if (result == true && mounted) {
                        _refreshOrders();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isProcessing
                                  ? Colors.blue
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isProcessing
                                  ? Icons.pending_actions
                                  : Icons.new_releases_outlined,
                              color: isProcessing
                                  ? Colors.white
                                  : Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ЗАКАЗ #${order.id.substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Создан: $formattedDate',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(order.status),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isNew = status == 'pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isNew
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isNew ? 'НОВЫЙ' : 'В СБОРКЕ',
        style: TextStyle(
          color: isNew ? Colors.orange.shade900 : Colors.blue.shade900,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
