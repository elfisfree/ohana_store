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

      final order = Order.fromJson(results[0] as Map<String, dynamic>);
      final reviewedItemIds = (results[1] as List)
          .map<String>((item) => item['order_item_id'] as String)
          .toSet();
      final history = results[2] as List<dynamic>;

      return (order, reviewedItemIds, history);
    } catch (e) {
      print("Error fetching order details: $e");
      throw Exception('Не удалось загрузить данные');
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
      case 'returned':
        return 'ОТМЕНЕН';
      case 'return_requested':
        return 'ЗАЯВКА НА ВОЗВРАТ';
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
    final bool isAnyStaff =
        widget.isAdmin || widget.isCollector || widget.isCourier;

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
                  if (widget.isAdmin) _buildAdminControls(order.status),
                  if (widget.isCollector) _buildCollectorButtons(order.status),
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
                  _buildTotalCard(order, useDark, f),

                  if (!isAnyStaff &&
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
    String displayAddress = "";
    String deliveryLabel = "";

    if (order.deliveryMethod == 'courier') {
      deliveryLabel = 'ДОСТАВКА КУРЬЕРОМ';
      displayAddress = order.shippingAddress ?? "Адрес не указан";
    } else {
      deliveryLabel = 'САМОВЫВОЗ (ИЗ МАГАЗИНА)';
      displayAddress = 'пр-т. Победы, 141, Казань, Респ. Татарстан, Россия';
    }

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
          _infoLine(
            'ЗАКАЗ',
            '#${order.id.substring(0, 8).toUpperCase()}',
            text,
            sub,
          ),
          _infoLine('СТАТУС', _translateStatus(order.status), text, sub),
          _infoLine(
            'ОПЛАТА',
            order.paymentStatus == 'succeeded' ? 'ОПЛАЧЕНО' : 'ОЖИДАЕТ',
            order.paymentStatus == 'succeeded' ? Colors.green : Colors.orange,
            sub,
          ),

          const Divider(height: 30, color: Colors.white10),

          Text(
            deliveryLabel,
            style: TextStyle(
              color: sub,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                order.deliveryMethod == 'courier'
                    ? Icons.local_shipping_outlined
                    : Icons.storefront_outlined,
                size: 20,
                color: dark ? AdminColors.accentBlue : Colors.black87,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayAddress,
                  style: TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminControls(String status) {
    if (status != 'pending' && status != 'processing' && status != 'shipped') {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          if (status == 'pending')
            ElevatedButton(
              onPressed: () => _updateOrderStatus('processing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.accentBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('ОТПРАВИТЬ НА СБОРКУ'),
            ),
          const SizedBox(height: 10),
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
    if (status == 'pending' || status == 'processing') {
      return Column(
        children: [
          ElevatedButton(
            onPressed: () => _updateOrderStatus(
              status == 'pending' ? 'processing' : 'shipped',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'pending' ? Colors.blue : Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
            ),
            child: Text(status == 'pending' ? 'НАЧАТЬ СБОРКУ' : 'СОБРАНО'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _showStaffCancelDialog,
            icon: const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 18,
            ),
            label: const Text(
              'ОТМЕНИТЬ (БРАК / НЕТ ТОВАРА)',
              style: TextStyle(color: Colors.redAccent),
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
    String status,
    bool staff,
    Color color,
    Color text,
    Color sub,
    NumberFormat f,
  ) {
    // ignore: unused_local_variable
    final bool isAnyStaff =
        widget.isAdmin || widget.isCollector || widget.isCourier;
    final bool canReview =
        !staff && status == 'delivered' && !reviewedIds.contains(item.id);
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
        border: staff && !widget.isAdmin
            ? Border.all(color: Colors.grey.shade200)
            : null,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 60,
              height: 60,
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
                  style: TextStyle(color: text, fontWeight: FontWeight.bold),
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
                        setState(() {
                          _orderDataFuture = _fetchAllOrderData();
                        });
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
            style: TextStyle(color: text, fontWeight: FontWeight.bold),
          ),
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
