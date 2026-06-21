// lib/features/delivery/courier_order_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/order.dart';

class CourierOrderPage extends StatefulWidget {
  final String orderId;
  const CourierOrderPage({super.key, required this.orderId});

  @override
  State<CourierOrderPage> createState() => _CourierOrderPageState();
}

class _CourierOrderPageState extends State<CourierOrderPage> {
  late Future<Order> _orderFuture;

  final Map<String, bool> _itemsKeptStatus = {};
  String _paymentType = 'card';
  final _receiptController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrder();
  }

  Future<Order> _fetchOrder() async {
    try {
      final response = await supabase
          .from('orders')
          .select(
            '*, order_items(*, product_variants(*), products(*, brands(*)))',
          )
          .eq('id', widget.orderId)
          .single();

      final order = Order.fromJson(response);

      if (_itemsKeptStatus.isEmpty) {
        setState(() {
          for (var item in order.items) {
            _itemsKeptStatus[item.id] = true;
          }
        });
      }
      return order;
    } catch (e) {
      print('ОШИБКА ЗАГРУЗКИ: $e');
      rethrow;
    }
  }

  // --- МЕТОД 1: ЛОГИКА ОТМЕНЫ ---
  Future<void> _cancelOrder(String reason) async {
    setState(() => _isSaving = true);
    try {
      await supabase
          .from('orders')
          .update({'status': 'cancelled', 'cancellation_reason': reason})
          .eq('id', widget.orderId);

      // Наш SQL триггер в базе сам вернет товары на склад!

      if (mounted) {
        AppNotifications.showSuccess(context, 'Заказ отменен');
        Navigator.pop(context, true); // Возвращаемся в список и обновляем его
      }
    } catch (e) {
      AppNotifications.showError(context, 'Ошибка отмены: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- МЕТОД 2: ДИАЛОГ ОТМЕНЫ ---
  void _showCancelDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'ПРИЧИНА ОТМЕНЫ',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Опишите причину отказа...',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('НАЗАД'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                AppNotifications.showError(context, 'Укажите причину');
                return;
              }
              Navigator.pop(ctx);
              _cancelOrder(controller.text.trim());
            },
            child: const Text(
              'ОТМЕНИТЬ ЗАКАЗ',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- ЛОГИКА ЗАВЕРШЕНИЯ (ВРУЧЕНИЯ) ---
  Future<void> _completeDelivery(Order order) async {
    if (_receiptController.text.isEmpty) {
      AppNotifications.showError(context, 'Введите номер чека');
      return;
    }

    setState(() => _isSaving = true);

    try {
      double finalSum = order.deliveryCost;
      for (var item in order.items) {
        if (_itemsKeptStatus[item.id] == true) {
          finalSum += (item.priceAtPurchase * item.quantity);
        }
      }

      for (var entry in _itemsKeptStatus.entries) {
        await supabase
            .from('order_items')
            .update({'is_kept': entry.value})
            .eq('id', entry.key);
      }

      await supabase
          .from('orders')
          .update({
            'status': 'delivered',
            'payment_status': 'succeeded',
            'actual_amount_paid': finalSum,
            'courier_payment_type': _paymentType,
            'courier_receipt_no': _receiptController.text.trim(),
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.orderId);

      if (mounted) {
        AppNotifications.showSuccess(context, 'Заказ успешно завершен!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppNotifications.showError(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'ПРИЕМ ОПЛАТЫ',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<Order>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data!;

          double currentTotal = order.deliveryCost;
          _itemsKeptStatus.forEach((id, kept) {
            if (kept) {
              final item = order.items.firstWhere((i) => i.id == id);
              currentTotal += (item.priceAtPurchase * item.quantity);
            }
          });

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'СОСТАВ ЗАКАЗА (ОТМЕТЬТЕ ВЫКУП)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 15),

                    ...order.items.map((item) => _buildFittingItem(item, f)),

                    const SizedBox(height: 30),
                    const Text(
                      'ДАННЫЕ ОБ ОПЛАТЕ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        _payTypeChip('КАРТА', 'card', Icons.credit_card),
                        const SizedBox(width: 10),
                        _payTypeChip(
                          'НАЛИЧНЫЕ',
                          'cash',
                          Icons.payments_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: _receiptController,
                      decoration: InputDecoration(
                        labelText: 'НОМЕР ЧЕКА / ТРАНЗАКЦИИ',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- КНОПКА ОТМЕНЫ ---
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _showCancelDialog,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('ОТМЕНИТЬ ЗАКАЗ ПОЛНОСТЬЮ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(25),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'К ОПЛАТЕ:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          f.format(currentTotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _completeDelivery(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'ПОДТВЕРДИТЬ И ВРУЧИТЬ',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Методы _buildFittingItem и _payTypeChip остаются такими же...
  Widget _buildFittingItem(OrderItem item, NumberFormat f) {
    final bool isKept = _itemsKeptStatus[item.id] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isKept ? Colors.grey.shade50 : Colors.red.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isKept
              ? Colors.grey.shade200
              : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: isKept ? 1 : 0.4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.variant?.imageUrls.first ?? "",
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.image),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isKept ? null : TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  '${item.size.toInt()} размер',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: isKept,
            activeColor: Colors.green,
            onChanged: (val) {
              setState(() => _itemsKeptStatus[item.id] = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _payTypeChip(String label, String value, IconData icon) {
    final bool isSelected = _paymentType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
