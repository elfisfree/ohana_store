// lib/features/admin/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/admin_stats.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<AdminStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchStats();
  }

  Future<AdminStats> _fetchStats() async {
    try {
      final response = await supabase
          .from('admin_dashboard_stats')
          .select()
          .single();
      return AdminStats.fromJson(response);
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
      throw Exception('Не удалось загрузить данные');
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
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _statsFuture = _fetchStats();
          });
          AppNotifications.showSuccess(context, 'Данные обновлены');
        },
        child: FutureBuilder<AdminStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AdminColors.accentBlue),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Ошибка: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final s = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(30),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'МОЁ ПРОСТРАНСТВО',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/admin/products/new'),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'ДОБАВИТЬ НОВЫЙ ТОВАР',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.accentBlue,
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

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 1.6,
                            children: [
                              _statCard(
                                'КЛИЕНТЫ',
                                s.totalCustomers.toString(),
                                0.7,
                                Colors.pinkAccent,
                                Icons.people_outline,
                              ),
                              _statCard(
                                'ТОВАРЫ',
                                s.totalProducts.toString(),
                                0.5,
                                Colors.orangeAccent,
                                Icons.inventory_2_outlined,
                              ),
                              _statCard(
                                'ЗАКАЗЫ',
                                s.totalOrders.toString(),
                                0.3,
                                AdminColors.accentBlue,
                                Icons.shopping_cart_outlined,
                              ),
                              _statCard(
                                'ОЖИДАЮТ',
                                s.pendingOrders.toString(),
                                0.1,
                                Colors.redAccent,
                                Icons.hourglass_empty_rounded,
                              ),
                              _statCard(
                                'ВЫРУЧКА',
                                f.format(s.totalRevenue),
                                0.9,
                                Colors.greenAccent,
                                Icons.payments_outlined,
                              ),
                              _statCard(
                                'СРЕДНИЙ ЧЕК',
                                f.format(s.avgCheck),
                                0.6,
                                Colors.purpleAccent,
                                Icons.analytics_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          _buildRecentActions(f),
                        ],
                      ),
                    ),

                    const SizedBox(width: 30),
                    Expanded(flex: 1, child: _buildShopOverview(s)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    double progress,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 1,
              color: color,
              backgroundColor: Colors.white10,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopOverview(AdminStats s) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          const Text(
            'ОБЗОР МАГАЗИНА',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 30),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 15,
                  color: AdminColors.accentBlue,
                  backgroundColor: Colors.white10,
                ),
              ),
              const Text(
                'Ohana\nStore',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _overviewRow(
            'Количество клиентов',
            s.totalCustomers.toString(),
            Icons.person,
            Colors.pinkAccent,
          ),
          _overviewRow(
            'Товары в наличии',
            s.totalProducts.toString(),
            Icons.inventory,
            Colors.orangeAccent,
          ),
          _overviewRow(
            'Активные заказы',
            s.pendingOrders.toString(),
            Icons.work,
            AdminColors.accentBlue,
          ),
        ],
      ),
    );
  }

  Widget _overviewRow(String title, String val, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActions(NumberFormat f) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ПОСЛЕДНИЕ СОБЫТИЯ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              const TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'СОБЫТИЕ',
                      style: TextStyle(
                        color: AdminColors.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'ДАТА',
                      style: TextStyle(
                        color: AdminColors.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'СТАТУС',
                      style: TextStyle(
                        color: AdminColors.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              _tableRow(
                'Добавлен новый товар Nike',
                'Сегодня, 14:20',
                'Выполнено',
              ),
              _tableRow(
                'Получен новый заказ #DE5962',
                'Вчера, 23:45',
                'Ожидает',
              ),
              _tableRow(
                'Промокод SPRING10 активирован',
                '04.05.2024',
                'Выполнено',
              ),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _tableRow(String act, String date, String status) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(
            act,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(
            date,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(
            status,
            style: const TextStyle(
              color: AdminColors.accentBlue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
