// lib/features/admin/admin_promocodes_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/promocode.dart';

class AdminPromocodesPage extends StatefulWidget {
  const AdminPromocodesPage({super.key});
  @override
  State<AdminPromocodesPage> createState() => _AdminPromocodesPageState();
}

class _AdminPromocodesPageState extends State<AdminPromocodesPage> {
  late Future<List<Promocode>> _promocodesFuture;

  @override
  void initState() {
    super.initState();
    _promocodesFuture = _fetchPromocodes();
  }

  Future<List<Promocode>> _fetchPromocodes() async {
    try {
      final response = await supabase
          .from('promocodes')
          .select('*, product_types(*)') // Сразу тянем типы для полноты
          .order('created_at', ascending: false);
      return response.map((p) => Promocode.fromJson(p)).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить промокоды: $e');
    }
  }

  Future<void> _deletePromocode(
    String promocodeId,
    String promocodeCode,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text(
          'УДАЛЕНИЕ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Вы уверены, что хотите удалить промокод "$promocodeCode"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('promocodes').delete().eq('id', promocodeId);
        AppNotifications.showSuccess(context, 'Промокод удален');
        setState(() => _promocodesFuture = _fetchPromocodes());
      } catch (e) {
        AppNotifications.showError(context, 'Ошибка удаления: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Фон через DesktopShell
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ШАПКА
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'МАРКЕТИНГОВЫЕ АКЦИИ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push('/admin/promocodes/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('СОЗДАТЬ ПРОМОКОД'),
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

            // ТАБЛИЦА
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AdminColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: FutureBuilder<List<Promocode>>(
                  future: _promocodesFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final promos = snapshot.data!;
                    if (promos.isEmpty) {
                      return const Center(
                        child: Text(
                          'Промокоды не найдены',
                          style: TextStyle(color: Colors.white24),
                        ),
                      );
                    }

                    return Theme(
                      data: ThemeData.dark().copyWith(
                        cardColor: AdminColors.card,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: DataTable(
                          headingTextStyle: const TextStyle(
                            color: AdminColors.accentBlue,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                          dataTextStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          horizontalMargin: 20,
                          columns: const [
                            DataColumn(label: Text('КОД')),
                            DataColumn(label: Text('СКИДКА')),
                            DataColumn(label: Text('ОГРАНИЧЕНИЕ')),
                            DataColumn(label: Text('СТАТУС')),
                            DataColumn(label: Text('ДЕЙСТВИЯ')),
                          ],
                          rows: promos
                              .map(
                                (p) => DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        p.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${p.discountPercentage.toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        p.minOrderAmount != null
                                            ? '${p.minOrderAmount!.toInt()} ₽'
                                            : 'Нет',
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (p.isActive
                                                      ? Colors.green
                                                      : Colors.red)
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          p.isActive ? 'АКТИВЕН' : 'ВЫКЛ',
                                          style: TextStyle(
                                            color: p.isActive
                                                ? Colors.green
                                                : Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          _actionButton(
                                            Icons.bar_chart_rounded,
                                            Colors.blue,
                                            () => context.push(
                                              '/admin/promocodes/report/${p.id}',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _actionButton(
                                            Icons.edit_note_rounded,
                                            Colors.orange,
                                            () => context.push(
                                              '/admin/promocodes/edit/${p.id}',
                                              extra: p,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _actionButton(
                                            Icons.delete_outline_rounded,
                                            Colors.redAccent,
                                            () =>
                                                _deletePromocode(p.id, p.code),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
