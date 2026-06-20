// lib/features/admin/admin_promocodes_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/features/admin/promocodes_provider.dart';
import 'package:provider/provider.dart';

class AdminPromocodesPage extends StatelessWidget {
  const AdminPromocodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PromocodesProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Expanded(
                  child: provider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AdminColors.accentBlue,
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AdminColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: SingleChildScrollView(
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
                              columns: const [
                                DataColumn(label: Text('КОД')),
                                DataColumn(label: Text('СКИДКА')),
                                DataColumn(label: Text('СТАТУС')),
                                DataColumn(label: Text('ДЕЙСТВИЯ')),
                              ],
                              rows: provider.promocodes
                                  .map(
                                    (p) => DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            p.code,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${p.discountPercentage.toInt()}%',
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                            ),
                                          ),
                                        ),
                                        DataCell(_buildStatusBadge(p.isActive)),
                                        DataCell(
                                          Row(
                                            children: [
                                              _actionBtn(
                                                Icons.bar_chart,
                                                Colors.blue,
                                                () => context.push(
                                                  '/admin/promocodes/report/${p.id}',
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _actionBtn(
                                                Icons.edit_note,
                                                Colors.orange,
                                                () => context.push(
                                                  '/admin/promocodes/edit/${p.id}',
                                                  extra: p,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _actionBtn(
                                                Icons.delete_outline,
                                                Colors.redAccent,
                                                () => _confirmDelete(
                                                  context,
                                                  p.id,
                                                  p.code,
                                                ),
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
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    final color = isActive ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'АКТИВЕН' : 'ВЫКЛ',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
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

  void _confirmDelete(BuildContext context, String id, String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text('УДАЛЕНИЕ', style: TextStyle(color: Colors.white)),
        content: Text('Удалить промокод $code?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('НЕТ'),
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
      await context.read<PromocodesProvider>().deletePromocode(id);
      AppNotifications.showSuccess(context, 'Промокод удален');
    }
  }
}
