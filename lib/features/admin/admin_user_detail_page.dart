// lib/features/admin/admin_user_detail_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/admin_theme.dart'; // Используем AdminColors
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/admin_user_model.dart';
import 'package:ohana_store/models/order.dart';

class AdminUserDetailPage extends StatefulWidget {
  final String userId;
  final AdminUser? user;

  const AdminUserDetailPage({super.key, required this.userId, this.user});

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  late Future<(AdminUser, List<Order>)> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchAllUserData();
  }

  Future<(AdminUser, List<Order>)> _fetchAllUserData() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.user != null
            ? Future.value(widget.user)
            : supabase
                  .from('admin_users_view')
                  .select()
                  .eq('id', widget.userId)
                  .single()
                  .then((data) => AdminUser.fromJson(data)),
        supabase
            .from('orders')
            .select()
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false),
      ]);

      final user = results[0] as AdminUser;
      final ordersList = results[1] as List;
      final orders = ordersList.map((o) => Order.fromJson(o)).toList();

      return (user, orders);
    } catch (e) {
      print('!!! ОШИБКА ЗАГРУЗКИ ДАННЫХ КЛИЕНТА: $e');
      throw Exception('Ошибка при загрузке данных клиента');
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
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text(
          'КАРТОЧКА КЛИЕНТА',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<(AdminUser, List<Order>)>(
        future: _userDataFuture,
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

          final user = snapshot.data!.$1;
          final orders = snapshot.data!.$2;

          // Расчет статистики
          final double totalSpent = orders.fold(
            0,
            (sum, o) => sum + o.finalPrice,
          );
          final int orderCount = orders.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ВЕРХНИЙ БЛОК: ПРОФИЛЬ И СТАТИСТИКА ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Основная инфо профиля
                    _buildProfileMainCard(user),
                    const SizedBox(width: 30),
                    // Статистика в ряд
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _statCard(
                                'ВСЕГО ЗАКАЗОВ',
                                orderCount.toString(),
                                Icons.shopping_bag_outlined,
                                AdminColors.accentBlue,
                              ),
                              const SizedBox(width: 20),
                              _statCard(
                                'ОБЩИЙ ЧЕК',
                                f.format(totalSpent),
                                Icons.account_balance_wallet_outlined,
                                Colors.greenAccent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildDetailsCard(user),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // --- НИЖНИЙ БЛОК: ТАБЛИЦА ЗАКАЗОВ ---
                const Text(
                  'ИСТОРИЯ ПОКУПОК',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                _buildOrdersTable(orders, f),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileMainCard(AdminUser user) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: AdminColors.sidebar,
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? const Icon(Icons.person, size: 60, color: Colors.white12)
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            '${user.firstName} ${user.lastName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            user.email,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: AdminColors.accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              user.role == 'admin' ? 'АДМИНИСТРАТОР' : 'ПОКУПАТЕЛЬ',
              style: const TextStyle(
                color: AdminColors.accentBlue,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(AdminUser user) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _infoRow(
            'Дата регистрации',
            DateFormat('dd.MM.yyyy').format(user.createdAt),
          ),
          const Divider(color: Colors.white10, height: 30),
          _infoRow(
            'Пол',
            user.gender == 'male'
                ? 'Мужской'
                : (user.gender == 'female' ? 'Женский' : 'Не указан'),
          ),
          const Divider(color: Colors.white10, height: 30),
          _infoRow(
            'Дата рождения',
            user.dateOfBirth != null
                ? DateFormat('dd.MM.yyyy').format(user.dateOfBirth!)
                : 'Не указана',
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTable(List<Order> orders, NumberFormat f) {
    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'Заказы не найдены',
          style: TextStyle(color: Colors.white24),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DataTable(
        headingTextStyle: const TextStyle(
          color: AdminColors.accentBlue,
          fontWeight: FontWeight.bold,
        ),
        dataTextStyle: const TextStyle(color: Colors.white),
        columns: const [
          DataColumn(label: Text('НОМЕР ЗАКАЗА')),
          DataColumn(label: Text('ДАТА')),
          DataColumn(label: Text('СТАТУС')),
          DataColumn(label: Text('СУММА')),
        ],
        rows: orders
            .map(
              (o) => DataRow(
                onSelectChanged: (_) => context.push('/admin/orders/${o.id}'),
                cells: [
                  DataCell(
                    Text(
                      '#${o.id.substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    Text(
                      DateFormat(
                        'dd.MM.yyyy HH:mm',
                      ).format(o.createdAt.toLocal()),
                    ),
                  ),
                  DataCell(
                    Text(
                      o.status.toUpperCase(),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  DataCell(
                    Text(
                      f.format(o.finalPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
