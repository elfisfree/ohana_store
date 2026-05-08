// lib/features/orders/orders_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/order.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  Future<List<Order>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<Order>> _fetchOrders() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((order) => Order.fromJson(order)).toList();
    } catch (e) {
      print('Ошибка загрузки заказов: $e');
      throw Exception('Не удалось загрузить историю заказов');
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _ordersFuture = _fetchOrders();
    });
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending':
        return 'В ожидании';
      case 'processing':
        return 'В обработке';
      case 'shipped':
        return 'Отправлен';
      case 'delivered':
        return 'Доставлен';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green.shade600;
      case 'processing':
        return Colors.blue.shade600;
      case 'shipped':
        return Colors.orange.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Мои заказы',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
      ),
      body: FutureBuilder<List<Order>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'У вас ещё нет заказов.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final currencyFormatter = NumberFormat.currency(
                  locale: 'ru_RU',
                  symbol: '₽',
                );
                final dateFormatter = DateFormat('dd MMM yyyy, HH:mm', 'ru');

                return GestureDetector(
                  onTap: () => context.push('/profile/orders/${order.id}'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .05),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Заказ",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "#${order.id.substring(0, 8)}",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              dateFormatter.format(order.createdAt.toLocal()),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyFormatter.format(order.totalPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  order.status,
                                ).withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _translateStatus(order.status),
                                style: TextStyle(
                                  color: _statusColor(order.status),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}
