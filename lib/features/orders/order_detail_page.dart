// lib/features/orders/order_detail_page.dart
// ignore_for_file: use_build_context_synchronously, unrelated_type_equality_checks

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/features/checkout/mock_payment_page.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/order.dart';

class ReviewDisplay {
  final double rating;
  final String? text;
  final DateTime createdAt;
  final String? userName;
  ReviewDisplay({
    required this.rating,
    this.text,
    required this.createdAt,
    this.userName,
  });
  factory ReviewDisplay.fromJson(Map<String, dynamic> json) {
    return ReviewDisplay(
      rating: (json['rating'] as num).toDouble(),
      text: json['review_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_full_name'] as String? ?? 'Аноним',
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  final bool isAdmin;
  final bool isCollector;
  final bool isCourier;

  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.isAdmin = false,
    this.isCollector = false,
    this.isCourier = false,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Future<(Order, Set<String>, List<dynamic>)> _orderDataFuture;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  String _adminPaymentType = 'card'; // По умолчанию карта
  final _adminReceiptController = TextEditingController();

  Map<String, bool> _keptItems = {};

  Map<String, int> _itemsQuantities = {};
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _orderDataFuture = _fetchAllOrderData();
  }

  @override
  void dispose() {
    _adminReceiptController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  double _calculateActualDiscount(Order order) {
    if (order.promoPercentage == null) return 0.0;

    double eligibleSubtotal = 0.0;
    for (var item in order.items) {
      // Считаем скидку только если товар выкуплен (quantityKept > 0)
      // и если тип товара подходит под промокод
      bool isEligible =
          order.promoTypeIds.isEmpty ||
          order.promoTypeIds.contains(item.product.productType?.id);

      if (isEligible) {
        eligibleSubtotal += (item.priceAtPurchase * item.quantityKept);
      }
    }
    return eligibleSubtotal * (order.promoPercentage! / 100);
  }

  Future<(Order, Set<String>, List<dynamic>)> _fetchAllOrderData() async {
    try {
      final orderItemsResponse = await supabase
          .from('order_items')
          .select('id')
          .eq('order_id', widget.orderId);
      final orderItemIds = orderItemsResponse
          .map((e) => e['id'] as String)
          .toList();

      final results = await Future.wait<dynamic>([
        supabase
            .from('orders')
            .select(
              '*, order_items(*, product_variants(*), products(*, brands(*)))',
            )
            .eq('id', widget.orderId)
            .single(),
        orderItemIds.isEmpty
            ? Future.value([])
            : supabase
                  .from('product_reviews')
                  .select('order_item_id')
                  .inFilter('order_item_id', orderItemIds),
        supabase
            .from('order_status_history')
            .select()
            .eq('order_id', widget.orderId)
            .order('changed_at', ascending: false),
      ]);

      return (
        Order.fromJson(results[0] as Map<String, dynamic>),
        (results[1] as List)
            .map<String>((e) => e['order_item_id'] as String)
            .toSet(),
        results[2] as List<dynamic>,
      );
    } catch (e) {
      print("Error: $e");
      throw Exception('Ошибка загрузки данных');
    }
  }

  Future<void> _cancelOrderByStaff(String reason) async {
    try {
      await supabase
          .from('orders')
          .update({'status': 'cancelled', 'cancellation_reason': reason})
          .eq('id', widget.orderId);

      if (mounted) {
        AppNotifications.showSuccess(
          context,
          'Заказ отменен и товары вернулись на склад',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка отмены: $e');
    }
  }

  void _showStaffCancelDialog() {
    final controller = TextEditingController();
    final bool useDark = widget.isAdmin;
    final Color dialogBg = useDark ? AdminColors.card : Colors.white;
    final Color textColor = useDark ? Colors.white : Colors.black;
    final Color inputBg = useDark ? AdminColors.sidebar : Colors.grey[100]!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'ПРИЧИНА ОТМЕНЫ',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Напр: Брак, нет в наличии...',
            hintStyle: TextStyle(color: useDark ? Colors.white24 : Colors.grey),
            filled: true,
            fillColor: inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'НАЗАД',
              style: TextStyle(
                color: useDark ? Colors.white60 : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                AppNotifications.showError(context, 'Укажите причину отмены');
                return;
              }
              Navigator.pop(ctx);
              _cancelOrderByStaff(controller.text.trim());
            },
            child: const Text(
              'ОТМЕНИТЬ ЗАКАЗ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', widget.orderId);

      if (mounted) {
        AppNotifications.showSuccess(context, 'Статус заказа обновлен');

        if (widget.isCourier || widget.isCollector) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _orderDataFuture = _fetchAllOrderData();
          });
        }
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка: $e');
    }
  }

  Future<void> _confirmCancellation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            (widget.isAdmin || widget.isCollector || widget.isCourier)
            ? AdminColors.card
            : Colors.white,
        title: Text(
          'ОТМЕНА ЗАКАЗА',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: (widget.isAdmin || widget.isCollector || widget.isCourier)
                ? Colors.white
                : Colors.black,
          ),
        ),
        content: Text(
          'Вы уверены? Действие нельзя отменить.',
          style: TextStyle(
            color: (widget.isAdmin || widget.isCollector || widget.isCourier)
                ? Colors.white70
                : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('НАЗАД'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ОТМЕНИТЬ'),
          ),
        ],
      ),
    );
    if (confirm == true) _updateOrderStatus('cancelled');
  }

  void _showReturnDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ПРИЧИНА ВОЗВРАТА'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Опишите причину...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _requestReturn(controller.text.trim());
            },
            child: const Text('ОТПРАВИТЬ'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestReturn(String reason) async {
    try {
      await supabase.from('return_requests').insert({
        'order_id': widget.orderId,
        'user_id': supabase.auth.currentUser!.id,
        'reason': reason,
      });
      await _updateOrderStatus('return_requested');
    } catch (e) {
      AppNotifications.showError(context, 'Ошибка: $e');
    }
  }

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'ОЖИДАЕТ';
      case 'processing':
        return 'В СБОРКЕ';
      case 'shipped':
        return 'ОТПРАВЛЕН';
      case 'delivered':
        return 'ДОСТАВЛЕН';
      case 'cancelled':
        return 'ОТМЕНЕН';
      case 'return_requested':
        return 'ЗАЯВКА НА ВОЗВРАТ';
      case 'returned':
        return 'ВОЗВРАЩЕНО';
      case 'ready_for_pickup':
        return 'ГОТОВ К ВЫДАЧЕ';
      default:
        return status.toUpperCase();
    }
  }

  void _startTimer(DateTime expiry) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final diff = expiry.difference(DateTime.now());
      setState(() {
        _timeLeft = diff.isNegative ? Duration.zero : diff;
      });
      if (_timeLeft == Duration.zero) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool useDark = widget.isAdmin;

    final Color bgColor = useDark ? AdminColors.background : Colors.grey[50]!;
    final Color cardColor = widget.isAdmin ? AdminColors.card : Colors.white;
    final Color textColor = widget.isAdmin ? Colors.white : Colors.black;
    final Color subTextColor = widget.isAdmin
        ? Colors.white38
        : Colors.grey[600]!;
    final Color dividerColor = widget.isAdmin
        ? Colors.white10
        : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'ДЕТАЛИ ЗАКАЗА',
          style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: FutureBuilder<(Order, Set<String>, List<dynamic>)>(
        future: _orderDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка: ${snapshot.error}',
                style: TextStyle(color: textColor),
              ),
            );
          }

          final order = snapshot.data!.$1;
          final reviewedIds = snapshot.data!.$2;
          final history = snapshot.data!.$3;

          if (!_isInitialized) {
            for (var item in order.items) {
              _keptItems[item.id] = true; // По умолчанию считаем, что берут всё
            }
            _isInitialized = true;
          }

          final bool isAnyStaff =
              widget.isAdmin || widget.isCollector || widget.isCourier;

          final f = NumberFormat.currency(
            locale: 'ru_RU',
            symbol: '₽',
            decimalDigits: 0,
          );

          if (order.paymentMethod == 'online' &&
              order.paymentStatus == 'pending' &&
              order.expiresAt != null &&
              _countdownTimer == null) {
            _startTimer(order.expiresAt!.toLocal());
          }

          final bool isReturnPeriodActive =
              order.deliveredAt != null &&
              DateTime.now().difference(order.deliveredAt!).inDays <= 14;

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildOrderCard(
                    order,
                    useDark,
                    textColor,
                    subTextColor,
                    dividerColor,
                  ),
                  if (order.status == 'cancelled' &&
                      order.cancellationReason != null)
                    _buildCancellationCard(
                      order.cancellationReason!,
                      isAnyStaff,
                    ),
                  if (widget.isAdmin) _buildAdminControls(order),
                  if (widget.isCollector) _buildCollectorButtons(order),
                  if (widget.isCourier) _buildCourierButtons(order.status),
                  if (!isAnyStaff)
                    _buildBuyerActions(order, isReturnPeriodActive),

                  const SizedBox(height: 30),
                  _buildStatusTimeline(
                    history,
                    useDark,
                    textColor,
                    dividerColor,
                  ),

                  const SizedBox(height: 30),
                  Text(
                    'СОСТАВ ЗАКАЗА',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  ...order.items.map(
                    (item) => _buildProductTile(
                      item,
                      reviewedIds,
                      order.status,
                      isAnyStaff,
                      cardColor,
                      textColor,
                      subTextColor,
                      f,
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildTotalCard(order, useDark, textColor, f),

                  if (!isAnyStaff &&
                      order.paymentMethod == 'online' &&
                      order.paymentStatus == 'pending' &&
                      !_timeLeft.isNegative &&
                      _timeLeft != Duration.zero)
                    _buildPaymentBlock(order),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(
    Order order,
    bool dark,
    Color text,
    Color sub,
    Color div,
  ) {
    final bool isAnyStaff =
        widget.isAdmin || widget.isCollector || widget.isCourier;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: dark ? AdminColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: dark ? null : Border.all(color: div),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoLine(
                'ЗАКАЗ',
                '#${order.id.substring(0, 8).toUpperCase()}',
                text,
                sub,
              ),
              if (order.withFitting)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'С ПРИМЕРКОЙ',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (isAnyStaff && order.paymentStatus == 'pending')
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ТРЕБУЕТСЯ ПРИНЯТЬ ОПЛАТУ ПРИ ВРУЧЕНИИ',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 15),
          _infoLine('СТАТУС', _translateStatus(order.status), text, sub),
          _infoLine(
            'ОПЛАТА',
            order.paymentStatus == 'succeeded' ? 'ОПЛАЧЕНО' : 'ОЖИДАЕТ',
            order.paymentStatus == 'succeeded' ? Colors.green : Colors.orange,
            sub,
          ),

          if (order.paymentStatus == 'succeeded') ...[
            const Divider(height: 30, color: Colors.black12),
            Text(
              'ДАННЫЕ ПЛАТЕЖА',
              style: TextStyle(
                color: sub,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _infoLine(
              'СПОСОБ',
              // Если это онлайн-оплата, пишем КАРТА (ОНЛАЙН)
              order.courierPaymentType == 'card'
                  ? 'КАРТА (ОНЛАЙН)'
                  : 'НАЛИЧНЫЕ',
              text,
              sub,
            ),
            _infoLine(
              'ЧЕК №',
              order.courierReceiptNo ?? 'Электронный чек',
              text,
              sub,
            ),
            _infoLine(
              'ДАТА ОПЛАТЫ',
              order.paidAt != null
                  ? DateFormat('dd.MM.yyyy HH:mm').format(order.paidAt!)
                  : 'Только что',
              text,
              sub,
            ),
          ],

          const Divider(height: 30, color: Colors.black12),

          Text(
            order.deliveryMethod == 'courier' ? 'АДРЕС ДОСТАВКИ' : 'САМОВЫВОЗ',
            style: TextStyle(
              color: sub,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.shippingAddress ??
                'пр-т. Победы, 141, Казань, Респ. Татарстан, Россия',
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminControls(Order order) {
    final status = order.status;
    final isUnpaid = order.paymentStatus == 'pending';

    if (status != 'pending' &&
        status != 'processing' &&
        status != 'shipped' &&
        status != 'ready_for_pickup') {
      return const SizedBox.shrink();
    }

    double currentTotal = order.deliveryCost;
    if (status == 'ready_for_pickup') {
      _keptItems.forEach((id, kept) {
        if (kept) {
          final item = order.items.firstWhere((i) => i.id == id);
          currentTotal += (item.priceAtPurchase * item.quantity);
        }
      });
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AdminColors.accentBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          if (status == 'ready_for_pickup') ...[
            const Text(
              'ОФОРМЛЕНИЕ ВЫДАЧИ (ПРИМЕРКА)',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 15),
            if (isUnpaid) ...[
              Row(
                children: [
                  _adminPayTypeButton('КАРТА', 'card', Icons.credit_card),
                  const SizedBox(width: 10),
                  _adminPayTypeButton(
                    'НАЛИЧНЫЕ',
                    'cash',
                    Icons.payments_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _adminReceiptController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'НОМЕР ЧЕКА / ТРАНЗАКЦИИ',
                  labelStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: AdminColors.sidebar,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 15,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            ElevatedButton.icon(
              onPressed: () {
                // Валидация перед выдачей
                if (isUnpaid && _adminReceiptController.text.trim().isEmpty) {
                  AppNotifications.showError(
                    context,
                    'Введите номер чека для закрытия заказа',
                  );
                  return;
                }
                _issuePickupOrder(order, currentTotal);
              },
              icon: Icon(
                isUnpaid ? Icons.payments_outlined : Icons.handshake_outlined,
              ),
              label: Text(
                isUnpaid
                    ? 'ПРИНЯТЬ ${currentTotal.toInt()} ₽ И ВЫДАТЬ'
                    : 'ВЫДАТЬ ВЫБРАННЫЕ ТОВАРЫ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnpaid
                    ? Colors.orange.shade800
                    : Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],

          if (status == 'pending')
            ElevatedButton(
              onPressed: () => _updateOrderStatus('processing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.accentBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ОТПРАВИТЬ НА СБОРКУ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: _confirmCancellation,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'ОТМЕНИТЬ ЗАКАЗ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminPayTypeButton(String label, String value, IconData icon) {
    bool isSelected = _adminPaymentType == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _adminPaymentType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AdminColors.accentBlue : AdminColors.sidebar,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.white24 : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white38,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _issuePickupOrder(Order order, double _) async {
    // 1. Если оплата при получении, проверяем номер чека
    if (order.paymentStatus == 'pending' &&
        _adminReceiptController.text.trim().isEmpty) {
      AppNotifications.showError(context, 'Введите номер чека для отчетности');
      return;
    }

    try {
      // 2. РАССЧИТЫВАЕМ ИТОГОВУЮ СУММУ ЗАНОВО (по количеству штук)
      // Берем только реально оставленное количество из нашей карты _itemsQuantities
      double totalForKeptItems = 0;

      // Проходим по всем товарам в заказе
      for (var item in order.items) {
        // Достаем из карты количество, которое админ оставил в списке
        // Если в карте пусто, берем исходное количество из заказа
        int keptCount = _itemsQuantities[item.id] ?? item.quantity;
        totalForKeptItems += (item.priceAtPurchase * keptCount);
      }

      // Финальная сумма = Товары + Доставка (хотя при самовывозе она обычно 0)
      double finalSumToPay = totalForKeptItems + order.deliveryCost;

      // 3. ОБНОВЛЯЕМ КОЛИЧЕСТВО В БАЗЕ ДАННЫХ
      for (var entry in _itemsQuantities.entries) {
        await supabase
            .from('order_items')
            .update({
              'quantity_kept': entry.value,
            }) // Теперь пишем ЧИСЛО, а не bool
            .eq('id', entry.key);
      }

      // 4. ЗАВЕРШАЕМ ЗАКАЗ
      await supabase
          .from('orders')
          .update({
            'status': 'delivered',
            'payment_status': 'succeeded',
            'actual_amount_paid': finalSumToPay, // Отправляем ПРАВИЛЬНУЮ сумму
            'courier_payment_type': _adminPaymentType,
            'courier_receipt_no': _adminReceiptController.text.trim(),
            'delivered_at': DateTime.now().toIso8601String(),
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.orderId);

      // 5. УВЕДОМЛЕНИЕ И ОБНОВЛЕНИЕ
      if (mounted) {
        AppNotifications.showSuccess(
          context,
          'Заказ выдан! Сумма оплаты: $finalSumToPay ₽',
        );

        setState(() {
          _isInitialized =
              false; // Сбрасываем флаг, чтобы при следующей загрузке данные обновились
          _adminReceiptController.clear();
          _orderDataFuture = _fetchAllOrderData();
        });
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Ошибка при выдаче заказа: $e');
      }
    }
  }

  Widget _buildCollectorButtons(Order order) {
    final status = order.status;
    final bool isPickup = order.deliveryMethod == 'pickup';

    if (status == 'pending' || status == 'processing') {
      return Column(
        children: [
          ElevatedButton(
            onPressed: () {
              if (status == 'pending') {
                _updateOrderStatus('processing');
              } else {
                // Если самовывоз - ставим готовность к выдаче, если нет - передаем курьеру
                _updateOrderStatus(isPickup ? 'ready_for_pickup' : 'shipped');
              }
            },
            style: ElevatedButton.styleFrom(
              // Динамический цвет: Синий для начала, Фиолетовый для выдачи, Зеленый для курьера
              backgroundColor: status == 'pending'
                  ? Colors.blue
                  : (isPickup ? Colors.purple : Colors.green),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              status == 'pending'
                  ? 'НАЧАТЬ СБОРКУ'
                  : (isPickup
                        ? 'ГОТОВ К ВЫДАЧЕ'
                        : 'СОБРАНО / ПЕРЕДАТЬ КУРЬЕРУ'),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _showStaffCancelDialog,
            icon: const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 18,
            ),
            label: const Text(
              'ОТМЕНИТЬ (БРАК / НЕТ ТОВАРА)',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCourierButtons(String status) {
    if (status == 'shipped') {
      return Column(
        children: [
          ElevatedButton(
            onPressed: () => _updateOrderStatus('delivered'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
            ),
            child: const Text('ЗАКАЗ ДОСТАВЛЕН'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _showStaffCancelDialog,
            child: const Text(
              'ОТМЕНА',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBuyerActions(Order order, bool isReturnActive) {
    return Column(
      children: [
        const SizedBox(height: 20),
        if (order.status == 'pending' || order.status == 'processing')
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _confirmCancellation,
              child: const Text('ОТМЕНИТЬ ЗАКАЗ'),
            ),
          ),
        if (order.status == 'delivered' && isReturnActive)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showReturnDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('ОФОРМИТЬ ВОЗВРАТ (14 ДНЕЙ)'),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusTimeline(
    List<dynamic> history,
    bool dark,
    Color text,
    Color div,
  ) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: dark ? AdminColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: dark ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ИСТОРИЯ СТАТУСОВ',
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 25),
          ...history.map(
            (item) => Row(
              children: [
                Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AdminColors.accentBlue,
                      size: 20,
                    ),
                    if (history.indexOf(item) != history.length - 1)
                      Container(
                        width: 2,
                        height: 25,
                        color: dark ? Colors.white10 : Colors.grey.shade200,
                      ),
                  ],
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translateStatus(item['status']),
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'dd MMMM, HH:mm',
                        'ru_RU',
                      ).format(DateTime.parse(item['changed_at']).toLocal()),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(
    OrderItem item,
    Set<String> reviewedIds,
    String orderStatus,
    bool staff,
    Color color,
    Color text,
    Color sub,
    NumberFormat f,
  ) {
    final bool isReturnedFull = item.quantityKept == 0;
    final bool isPartial =
        item.quantityKept > 0 && item.quantityKept < item.quantity;

    String imageUrl = "";
    if (item.variant != null && item.variant!.imageUrls.isNotEmpty) {
      imageUrl = item.variant!.imageUrls.first;
    } else if (item.product.variants.isNotEmpty) {
      imageUrl = item.product.variants.first.imageUrls.first;
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isReturnedFull
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // ФОТО
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Opacity(
              opacity: isReturnedFull ? 0.5 : 1.0,
              child: Image.network(
                imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 15),

          // ИНФОРМАЦИЯ (Название, размер, выкуп)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    decoration: isReturnedFull
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Размер: ${item.size.toInt()}',
                      style: TextStyle(color: sub, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isReturnedFull
                            ? Colors.red.withValues(alpha: 0.1)
                            : AdminColors.accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isReturnedFull
                            ? 'ВОЗВРАТ'
                            : 'ВЫКУП: ${item.quantityKept} из ${item.quantity} шт.',
                        style: TextStyle(
                          color: isReturnedFull
                              ? Colors.red
                              : AdminColors.accentBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                f.format(item.priceAtPurchase * item.quantityKept),
                style: TextStyle(color: text, fontWeight: FontWeight.w900),
              ),
              if (isPartial || isReturnedFull)
                Text(
                  'было: ${f.format(item.priceAtPurchase * item.quantity)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(Order order, bool dark, Color text, NumberFormat f) {
    final bool isDelivered = order.status == 'delivered';
    final double actualDiscount = _calculateActualDiscount(order);

    // Был ли частичный выкуп?
    final bool isPriceChanged =
        isDelivered && (order.actualAmountPaid - order.finalPrice).abs() > 1.0;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: dark ? AdminColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: dark ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // 1. Изначальный расчет (как планировалось)
          _summaryRow(
            'СУММА ЗАКАЗА',
            f.format(order.totalPrice),
            text,
            isLineThrough: isPriceChanged,
          ),
          if (order.discountAmount > 0)
            _summaryRow(
              'СКИДКА ПО АКЦИИ',
              '-${f.format(order.discountAmount)}',
              Colors.redAccent,
              isLineThrough: isPriceChanged,
            ),

          _summaryRow('ДОСТАВКА', f.format(order.deliveryCost), text),

          if (isPriceChanged) ...[
            const Divider(height: 30, color: Colors.black12),
            // 2. Фактический расчет (после примерки)
            const Text(
              'ФАКТИЧЕСКИЙ РАСЧЕТ',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Показываем реальную скидку на выкупленные вещи
            if (actualDiscount > 0)
              _summaryRow(
                'ИТОГОВАЯ СКИДКА',
                '-${f.format(actualDiscount)}',
                Colors.green,
              ),

            _summaryRow(
              'ИТОГО ОПЛАЧЕНО',
              f.format(order.actualAmountPaid),
              Colors.green,
              isBold: true,
            ),
          ] else ...[
            const Divider(height: 30, color: Colors.black12),
            _summaryRow(
              'ИТОГО К ОПЛАТЕ',
              f.format(order.finalPrice),
              text,
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }

  // Вспомогательный метод для строк в чеке
  Widget _summaryRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    bool isLineThrough = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.normal : FontWeight.bold,
              fontSize: isBold ? 20 : 14,
              decoration: isLineThrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationCard(String reason, bool isStaff) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                'ПРИЧИНА ОТМЕНЫ',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reason,
            style: TextStyle(
              color: isStaff ? Colors.white : Colors.black87,
              fontSize: 15,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBlock(Order order) {
    return Container(
      margin: const EdgeInsets.only(top: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text(
            'ОЖИДАЕТ ОПЛАТЫ',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 10),
          Text(
            'Осталось: ${_timeLeft.inMinutes}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final success = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MockPaymentPage(
                    orderId: order.id,
                    amount: order.finalPrice,
                  ),
                ),
              );
              if (success == true) {
                setState(() {
                  _orderDataFuture = _fetchAllOrderData();
                });
              }
            },
            child: const Text('ОПЛАТИТЬ СЕЙЧАС'),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: sub,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
