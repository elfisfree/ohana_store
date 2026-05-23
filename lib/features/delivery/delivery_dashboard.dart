// lib/features/delivery/delivery_dashboard.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/order.dart';

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  late Future<List<Order>> _deliveryOrders;

  @override
  void initState() {
    super.initState();
    _deliveryOrders = _fetchDeliveryOrders();
  }

  Future<List<Order>> _fetchDeliveryOrders() async {
    final response = await supabase
        .from('orders')
        .select()
        .eq('status', 'shipped')
        .order('created_at', ascending: true);

    return (response as List).map((o) => Order.fromJson(o)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ДОСТАВКА',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<Order>>(
        future: _deliveryOrders,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;

          if (orders.isEmpty) {
            return const Center(child: Text('Нет заказов для доставки'));
          }

          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _deliveryOrders = _fetchDeliveryOrders()),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_shipping,
                      color: Colors.orange,
                    ),
                    title: Text('Заказ #${order.id.substring(0, 8)}'),
                    subtitle: Text(
                      'Адрес: ${order.shippingAddress ?? 'Самовывоз'}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => context.push('/delivery/order/${order.id}'),
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
