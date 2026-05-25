// lib/features/delivery/delivery_dashboard.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
// ignore: unused_import
import 'package:ohana_store/models/order.dart';
import 'package:url_launcher/url_launcher.dart'; // Пакет для звонков и карт

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  late Future<List<dynamic>> _deliveryOrders;

  @override
  void initState() {
    super.initState();
    _deliveryOrders = _fetchDeliveryOrders();
  }

  Future<List<dynamic>> _fetchDeliveryOrders() async {
    // Используем наше новое вью, чтобы видеть телефон клиента
    final response = await supabase
        .from('delivery_orders_view')
        .select()
        .eq('status', 'shipped')
        .order('created_at', ascending: true);

    return response as List<dynamic>;
  }

  // Метод для звонка клиенту
  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri url = Uri.parse(
      'tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'МАРШРУТНЫЙ ЛИСТ',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _deliveryOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Все заказы доставлены!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _deliveryOrders = _fetchDeliveryOrders()),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final o = orders[index];
                final String customerName =
                    "${o['first_name']} ${o['last_name']}";

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => context.push('/delivery/order/${o['id']}'),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ЗАКАЗ #${o['id'].substring(0, 8).toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                f.format(o['final_price']),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 25),
                          if (o['shipped_at'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                    color: Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'СОБРАН: ${DateFormat('dd.MM HH:mm').format(DateTime.parse(o['shipped_at']).toLocal())}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Показываем "Срочность" (опционально)
                                  _buildPriorityBadge(
                                    DateTime.parse(o['shipped_at']),
                                  ),
                                ],
                              ),
                            ),

                          // --- КЛИЕНТ ---
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // --- АДРЕС (КРУПНО) ---
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 20,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  o['shipping_address'] ?? 'Самовывоз',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // --- БЫСТРЫЕ ДЕЙСТВИЯ ---
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _makeCall(o['customer_phone']),
                                  icon: const Icon(Icons.phone),
                                  label: const Text('ПОЗВОНИТЬ'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.map_outlined,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () async {
                                    // Открываем карты с адресом
                                    final String address =
                                        o['shipping_address'] ?? '';
                                    if (address.isEmpty ||
                                        address == 'Самовывоз') {
                                      return;
                                    }

                                    final String encodedAddress =
                                        Uri.encodeComponent(address);

                                    // Самая надежная ссылка для РФ (открывает приложение Яндекс.Карт или браузер)
                                    final Uri url = Uri.parse(
                                      "https://yandex.ru/maps/?text=$encodedAddress",
                                    );

                                    try {
                                      // Мы сразу вызываем запуск в режиме внешней программы
                                      await launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } catch (e) {
                                      // Если на телефоне вообще нет карт и браузера (что невозможно), покажем ошибку
                                      AppNotifications.showError(
                                        context,
                                        'Не удалось открыть карту',
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
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
}

Widget _buildPriorityBadge(DateTime shippedAt) {
  final diff = DateTime.now().difference(shippedAt).inHours;

  Color color = Colors.green;
  String text = 'СВЕЖИЙ';

  if (diff >= 3) {
    color = Colors.orange;
    text = 'СРОЧНО';
  }
  if (diff >= 6) {
    color = Colors.red;
    text = 'ГОРЯЩИЙ';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}
