// lib/features/delivery/courier_order_page.dart
// ignore_for_file: use_build_context_synchronously, prefer_final_fields

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

  String _paymentType = 'card';
  final _receiptController = TextEditingController();
  bool _isSaving = false;

  Map<String, int> _itemsQuantities = {};

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrder();
  }

  Future<Order> _fetchOrder() async {
    try {
      final response = await supabase
          .from('orders_with_details') // ГЛАВНОЕ ИСПРАВЛЕНИЕ
          .select('''
            *, 
            order_items (
              *, 
              products (*, brands(*), product_types(*)), 
              product_variants (*)
            )
          ''')
          .eq('id', widget.orderId)
          .single();

      final order = Order.fromJson(response);
      if (_itemsQuantities.isEmpty) {
        setState(() {
          for (var item in order.items) {
            _itemsQuantities[item.id] = item.quantity;
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

  Future<void> _completeDelivery(Order order) async {
    // 1. Валидация чека (только если не было онлайн-оплаты)
    if (order.paymentStatus != 'succeeded' && _receiptController.text.isEmpty) {
      AppNotifications.showError(context, 'Введите номер чека');
      return;
    }

    setState(() => _isSaving = true);

    try {
      double totalForKeptItems = 0; // Сумма выкупленных товаров без скидки
      double totalDiscountForKeptItems =
          0; // Сумма скидки на выкупленные товары

      // 2. УМНЫЙ РАСЧЕТ СУММЫ С УЧЕТОМ ПРОМОКОДА
      _itemsQuantities.forEach((itemId, keptQty) {
        if (keptQty > 0) {
          final item = order.items.firstWhere((i) => i.id == itemId);
          double itemSubtotal = item.priceAtPurchase * keptQty;

          // Проверяем: действует ли промокод на этот конкретный товар?
          // Условие: промокод существует И (список типов пуст [значит на всё] ИЛИ тип товара в списке разрешенных)
          bool isPromoApplicable =
              order.promoPercentage != null &&
              (order.promoTypeIds.isEmpty ||
                  order.promoTypeIds.contains(item.product.productType?.id));

          if (isPromoApplicable) {
            // Рассчитываем скидку только для этого количества и этого товара
            totalDiscountForKeptItems +=
                itemSubtotal * (order.promoPercentage! / 100);
          }

          totalForKeptItems += itemSubtotal;
        }
      });

      // Итоговая сумма = (Товары) - (Скидка на них) + (Доставка)
      double finalSumToPay =
          totalForKeptItems - totalDiscountForKeptItems + order.deliveryCost;

      // 3. Обновляем количества в базе (сколько штук выкуплено)
      for (var entry in _itemsQuantities.entries) {
        await supabase
            .from('order_items')
            .update({'quantity_kept': entry.value})
            .eq('id', entry.key);
      }

      // 4. Завершаем заказ в базе
      await supabase
          .from('orders')
          .update({
            'status': 'delivered',
            'payment_status': 'succeeded',
            'actual_amount_paid': finalSumToPay, // Отправляем ЧЕСТНУЮ сумму
            'courier_payment_type': _paymentType,
            'courier_receipt_no': _receiptController.text.trim(),
            'delivered_at': DateTime.now().toIso8601String(),
            'paid_at': DateTime.now()
                .toIso8601String(), // Фиксируем время оплаты
          })
          .eq('id', widget.orderId);

      // SQL-Триггер в Supabase сам увидит разницу (quantity - quantity_kept)
      // и вернет невыкупленные пары на склад.

      if (mounted) {
        AppNotifications.showSuccess(
          context,
          'Заказ завершен. Принято: ${finalSumToPay.toInt()} ₽',
        );
        Navigator.pop(context, true); // Возвращаемся в список
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка сохранения: $e');
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

          double totalForKeptItems = 0;
          double totalDiscountAmount = 0;
          _itemsQuantities.forEach((itemId, keptQty) {
            if (keptQty > 0) {
              final item = order.items.firstWhere((i) => i.id == itemId);
              double itemSubtotal = item.priceAtPurchase * keptQty;

              // Проверяем, действует ли промокод на этот товар
              bool isPromoApplicable =
                  order.promoPercentage != null &&
                  (order.promoTypeIds.isEmpty ||
                      order.promoTypeIds.contains(
                        item.product.productType?.id,
                      ));

              if (isPromoApplicable) {
                totalDiscountAmount +=
                    itemSubtotal * (order.promoPercentage! / 100);
              }

              totalForKeptItems += itemSubtotal;
            }
          });
          double currentTotal =
              totalForKeptItems - totalDiscountAmount + order.deliveryCost;

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
                    if (order.paymentStatus == 'pending')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'ТРЕБУЕТСЯ ПРИНЯТЬ ОПЛАТУ!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (order.paymentStatus != 'succeeded') ...[
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
                    ] else ...[
                      // Если оплачено онлайн, показываем просто информационную плашку
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'ЗАКАЗ ОПЛАЧЕН ОНЛАЙН',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  Widget _buildFittingItem(OrderItem item, NumberFormat f) {
    // Получаем текущее выбранное количество из локального состояния
    // (в initState нужно будет создать Map<String, int> _itemsQuantities)
    final int currentKept = _itemsQuantities[item.id] ?? item.quantity;
    final bool isReturnedFull = currentKept == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isReturnedFull
            ? Colors.red.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isReturnedFull
              ? Colors.redAccent.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.variant?.imageUrls.first ?? "",
              width: 50,
              height: 50,
              fit: BoxFit.cover,
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
                    decoration: isReturnedFull
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  '${item.size.toInt()} размер | Заказано: ${item.quantity} шт.',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),

          // --- НОВЫЙ БЛОК: СЧЕТЧИК ВЫКУПА ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () {
                    if (currentKept > 0) {
                      setState(
                        () => _itemsQuantities[item.id] = currentKept - 1,
                      );
                    }
                  },
                ),
                Text(
                  '$currentKept',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () {
                    if (currentKept < item.quantity) {
                      setState(
                        () => _itemsQuantities[item.id] = currentKept + 1,
                      );
                    }
                  },
                ),
              ],
            ),
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
