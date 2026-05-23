// lib/features/orders/order_detail_page.dart
// ignore_for_file: use_build_context_synchronously

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

  @override
  void initState() {
    super.initState();
    _orderDataFuture = _fetchAllOrderData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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
        Order.fromJson(results[0]),
        (results[1] as List)
            .map<String>((e) => e['order_item_id'] as String)
            .toSet(),
        results[2] as List<dynamic>,
      );
    } catch (e) {
      print("Error fetching order details: $e");
      throw Exception('Ошибка загрузки данных');
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', widget.orderId);

      if (mounted) {
        AppNotifications.showSuccess(context, 'Статус обновлен');
        setState(() {
          _orderDataFuture = _fetchAllOrderData();
        });
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка: $e');
    }
  }

  Future<void> _confirmCancellation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isAdmin ? AdminColors.card : Colors.white,
        title: const Text(
          'ОТМЕНА ЗАКАЗА',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('НЕТ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ДА'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _updateOrderStatus('cancelled');
    }
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
      AppNotifications.showSuccess(context, 'Заявка на возврат отправлена');
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
        return 'В ПУТИ';
      case 'delivered':
        return 'ДОСТАВЛЕН';
      case 'cancelled':
        return 'ОТМЕНЕН';
      case 'return_requested':
        return 'ЗАЯВКА НА ВОЗВРАТ';
      case 'returned':
        return 'ВОЗВРАЩЕНО';
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
    final bool isStaff =
        widget.isAdmin || widget.isCollector || widget.isCourier;
    final Color textColor = isStaff ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isStaff ? AdminColors.background : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'ДЕТАЛИ ЗАКАЗА',
          style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: FutureBuilder<(Order, Set<String>, List<dynamic>)>(
        future: _orderDataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final order = snapshot.data!.$1;
          final reviewedIds = snapshot.data!.$2;
          final history = snapshot.data!.$3;
          final f = NumberFormat.currency(
            locale: 'ru_RU',
            symbol: '₽',
            decimalDigits: 0,
          );

          if (order.paymentStatus == 'pending' &&
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
                  _buildOrderCard(order, isStaff),
                  if (widget.isAdmin) _buildAdminControls(order.status),
                  if (widget.isCollector) _buildCollectorButtons(order.status),
                  if (widget.isCourier) _buildCourierButtons(order.status),
                  if (!isStaff) _buildBuyerActions(order, isReturnPeriodActive),

                  const SizedBox(height: 30),
                  _buildStatusTimeline(history, isStaff),

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
                      isStaff,
                      f,
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildTotalCard(order, isStaff, f),

                  if (!isStaff &&
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

  Widget _buildProductTile(
    OrderItem item,
    Set<String> reviewedIds,
    String orderStatus,
    bool isStaff,
    NumberFormat f,
  ) {
    String imageUrl = "";
    if (item.variant != null && item.variant!.imageUrls.isNotEmpty) {
      imageUrl = item.variant!.imageUrls.first;
    } else if (item.product.variants.isNotEmpty &&
        item.product.variants.first.imageUrls.isNotEmpty) {
      imageUrl = item.product.variants.first.imageUrls.first;
    }

    final bool canReview =
        !widget.isAdmin &&
        !widget.isCollector &&
        !widget.isCourier &&
        orderStatus == 'delivered' &&
        !reviewedIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isStaff ? AdminColors.card : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isStaff ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported),
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
                    color: isStaff ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Размер: ${item.size.toInt()}, Цвет: ${item.variant?.colorName ?? 'Базовый'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                if (canReview)
                  TextButton(
                    onPressed: () async {
                      final res = await context.push(
                        '/add-review',
                        extra: {
                          'order_item_id': item.id,
                          'product_id': item.product.id,
                        },
                      );
                      if (res == true) {
                        setState(() => _orderDataFuture = _fetchAllOrderData());
                      }
                    },
                    child: const Text(
                      'ОСТАВИТЬ ОТЗЫВ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            f.format(item.priceAtPurchase),
            style: TextStyle(
              color: isStaff ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildAdminControls(String status) {
    final bool canSend = status == 'pending';
    final bool canCancel =
        status != 'cancelled' &&
        status != 'delivered' &&
        status != 'returned' &&
        status != 'return_requested';
    if (!canSend && !canCancel) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          if (canSend)
            ElevatedButton(
              onPressed: () => _updateOrderStatus('processing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.accentBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('ОТПРАВИТЬ НА СБОРКУ'),
            ),
          if (canSend && canCancel) const SizedBox(height: 10),
          if (canCancel)
            OutlinedButton(
              onPressed: _confirmCancellation,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('ОТМЕНИТЬ ЗАКАЗ'),
            ),
        ],
      ),
    );
  }

  Widget _buildCollectorButtons(String status) {
    if (status != 'processing') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: () => _updateOrderStatus('shipped'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
        ),
        child: const Text(
          'СОБРАНО / ПЕРЕДАТЬ КУРЬЕРУ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildCourierButtons(String status) {
    if (status != 'shipped') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: () => _updateOrderStatus('delivered'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade800,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
        ),
        child: const Text(
          'ЗАКАЗ ДОСТАВЛЕН КЛИЕНТУ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(List<dynamic> history, bool isStaff) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: isStaff ? AdminColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isStaff ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ИСТОРИЯ СТАТУСОВ',
            style: TextStyle(
              color: isStaff ? Colors.white : Colors.black,
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
                        color: isStaff ? Colors.white10 : Colors.grey.shade200,
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
                        color: isStaff ? Colors.white : Colors.black,
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

  Widget _buildOrderCard(Order order, bool isStaff) {
    final text = isStaff ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: isStaff ? AdminColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isStaff ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _infoLine(
            'ЗАКАЗ',
            '#${order.id.substring(0, 8).toUpperCase()}',
            text,
            Colors.grey,
          ),
          _infoLine(
            'СТАТУС',
            _translateStatus(order.status),
            text,
            Colors.grey,
          ),
          _infoLine(
            'ОПЛАТА',
            order.paymentStatus == 'succeeded' ? 'ОПЛАЧЕНО' : 'ОЖИДАЕТ',
            order.paymentStatus == 'succeeded' ? Colors.green : Colors.orange,
            Colors.grey,
          ),
          if (order.shippingAddress != null)
            _infoLine('АДРЕС', order.shippingAddress!, text, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildTotalCard(Order order, bool isStaff, NumberFormat f) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: isStaff ? AdminColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isStaff ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ИТОГО К ОПЛАТЕ',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          Text(
            f.format(order.finalPrice),
            style: TextStyle(
              color: isStaff ? AdminColors.accentBlue : Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w900,
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
                setState(() => _orderDataFuture = _fetchAllOrderData());
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
