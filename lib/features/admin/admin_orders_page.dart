// lib/features/admin/admin_orders_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:go_router/go_router.dart';

class AdminOrder {
  final String id;
  final DateTime createdAt;
  final double totalPrice;
  final double finalPrice;
  final String status;
  final String customerName;
  final String paymentStatus;
  final bool withFitting;
  final double actualAmountPaid;
  final int totalItems;

  AdminOrder({
    required this.id,
    required this.createdAt,
    required this.totalPrice,
    required this.finalPrice,
    required this.status,
    required this.customerName,
    required this.paymentStatus,
    required this.withFitting,
    required this.actualAmountPaid,
    required this.totalItems,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] as String? ?? '';
    final lastName = json['last_name'] as String? ?? '';
    return AdminOrder(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      totalPrice: (json['total_price'] as num).toDouble(),
      finalPrice: (json['final_price'] as num).toDouble(),
      status: json['status'],
      customerName: '$firstName $lastName'.trim().isNotEmpty
          ? '$firstName $lastName'
          : 'Неизвестный',
      paymentStatus: json['payment_status'] ?? 'pending',
      withFitting: json['with_fitting'] ?? false,
      actualAmountPaid: (json['actual_amount_paid'] as num?)?.toDouble() ?? 0.0,
      totalItems: json['total_items'] ?? 0,
    );
  }
}

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  late Future<List<AdminOrder>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<AdminOrder>> _fetchOrders() async {
    try {
      final response = await supabase
          .from('orders_with_details')
          .select('*')
          .order('created_at', ascending: false);
      return response.map((o) => AdminOrder.fromJson(o)).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить заказы');
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await supabase.from('orders').update({'status': newStatus}).eq('id', id);
      if (mounted) {
        AppNotifications.showSuccess(context, 'Статус обновлен');
        setState(() {
          _ordersFuture = _fetchOrders();
        });
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ШАПКА ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ЖУРНАЛ ЗАКАЗОВ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Оперативное управление продажами и примерками',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _ordersFuture = _fetchOrders();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('ОБНОВИТЬ ДАННЫЕ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.card,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- СПИСОК ЗАКАЗОВ ---
            Expanded(
              child: FutureBuilder<List<AdminOrder>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AdminColors.accentBlue,
                      ),
                    );
                  }
                  final orders = snapshot.data!;
                  if (orders.isEmpty) {
                    return const Center(
                      child: Text(
                        'Заказов пока нет',
                        style: TextStyle(color: Colors.white38),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final f = NumberFormat.currency(
                        locale: 'ru_RU',
                        symbol: '₽',
                        decimalDigits: 0,
                      );

                      // Проверка на частичный выкуп
                      final bool isPartialBuyout =
                          order.status == 'delivered' &&
                          order.actualAmountPaid > 0 &&
                          order.actualAmountPaid < order.finalPrice;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: AdminColors.card,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: InkWell(
                          // Делаем всю строку кликабельной
                          onTap: () => context.go('/admin/orders/${order.id}'),
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                _buildOrderInfo(order), // Обновим внутри
                                const Spacer(),
                                _buildCustomerInfo(order),
                                const SizedBox(width: 40),
                                _buildPriceInfo(
                                  order,
                                  f,
                                  isPartialBuyout,
                                ), // Обновим внутри
                                const SizedBox(width: 40),
                                _buildActionButtons(order),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo(AdminOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ЗАКАЗ #${order.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (order.withFitting) ...[
              const SizedBox(width: 10),
              Tooltip(
                message: 'Заказ с примеркой',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.checkroom,
                    color: Colors.orange,
                    size: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(
          DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt.toLocal()),
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo(AdminOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ПОКУПАТЕЛЬ',
          style: TextStyle(
            color: Colors.white24,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          order.customerName,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPriceInfo(
    AdminOrder order,
    NumberFormat f,
    bool isPartialBuyout,
  ) {
    // Проверяем: был ли частичный выкуп (заказ доставлен и сумма меньше исходной)
    final bool isPartialBuyout =
        order.status == 'delivered' &&
        order.actualAmountPaid > 0 &&
        order.actualAmountPaid < order.finalPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Если был возврат - показываем старую цену зачеркнутой
        if (isPartialBuyout)
          Text(
            f.format(order.finalPrice),
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
            ),
          ),

        // Показываем актуальную сумму (зеленым, если она изменилась)
        Text(
          isPartialBuyout
              ? f.format(order.actualAmountPaid)
              : f.format(order.finalPrice),
          style: TextStyle(
            color: isPartialBuyout ? Colors.greenAccent : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),

        Text(
          isPartialBuyout ? 'ЧАСТИЧНЫЙ ВЫКУП' : 'СУММА ЗАКАЗА',
          style: TextStyle(
            color: isPartialBuyout
                ? Colors.greenAccent.withValues(alpha: .5)
                : Colors.white10,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(AdminOrder order) {
    if (order.status == 'pending') {
      return Row(
        children: [
          _statusButton(
            'ОТМЕНИТЬ',
            Colors.redAccent,
            () => _confirmCancel(order.id),
          ),
          const SizedBox(width: 10),
          _statusButton(
            'В СБОРКУ',
            Colors.greenAccent,
            () => _updateStatus(order.id, 'processing'),
          ),
        ],
      );
    }
    if (order.status == 'processing' || order.status == 'shipped') {
      return Row(
        children: [
          _statusButton(
            'ОТМЕНИТЬ',
            Colors.redAccent,
            () => _confirmCancel(order.id),
          ),
          const SizedBox(width: 15),
          _statusBadge(order.status),
        ],
      );
    }
    return _statusBadge(order.status);
  }

  Widget _statusButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 35,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          foregroundColor: color,
          elevation: 0,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 15),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    String text = status.toUpperCase();
    if (status == 'processing') {
      color = Colors.blueAccent;
      text = 'В СБОРКЕ';
    }
    if (status == 'shipped') {
      color = Colors.purpleAccent;
      text = 'В ПУТИ';
    }
    if (status == 'delivered') {
      color = Colors.greenAccent;
      text = 'ДОСТАВЛЕН';
    }
    if (status == 'cancelled') {
      color = Colors.white24;
      text = 'ОТМЕНЕН';
    }
    if (status == 'returned') {
      color = Colors.white24;
      text = 'ВОЗВРАТ';
    }
    if (status == 'return_requested') {
      color = Colors.orangeAccent;
      text = 'ВОЗВРАТ (ЗАЯВКА)';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _confirmCancel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text('ОТМЕНА', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Вы действительно хотите отменить заказ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('НЕТ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ДА, ОТМЕНИТЬ'),
          ),
        ],
      ),
    );
    if (confirm == true) _updateStatus(id, 'cancelled');
  }
}
