// lib/features/admin/admin_returns_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:go_router/go_router.dart';

class AdminReturnsPage extends StatefulWidget {
  const AdminReturnsPage({super.key});

  @override
  State<AdminReturnsPage> createState() => _AdminReturnsPageState();
}

class _AdminReturnsPageState extends State<AdminReturnsPage> {
  late Future<List<dynamic>> _returnsFuture;

  @override
  void initState() {
    super.initState();
    _returnsFuture = _fetchReturns();
  }

  Future<List<dynamic>> _fetchReturns() async {
    try {
      final response = await supabase
          .from('returns_with_details')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      print('!!! ОШИБКА ЗАГРУЗКИ ВОЗВРАТОВ: $e');
      throw Exception('Не удалось загрузить данные');
    }
  }

  // --- ОБНОВЛЕННЫЙ МЕТОД ОБРАБОТКИ (С КОММЕНТАРИЕМ) ---
  Future<void> _handleReturn(
    String requestId,
    String orderId,
    String newStatus, {
    String? adminComment,
  }) async {
    try {
      // 1. Обновляем заявку в таблице return_requests
      await supabase
          .from('return_requests')
          .update({
            'status': newStatus,
            if (adminComment != null) 'admin_comment': adminComment,
          })
          .eq('id', requestId);

      // 2. Определяем новый статус заказа
      // Если одобрено -> returned (возвращено)
      // Если отклонено -> return_rejected (в возврате отказано)
      final String orderStatus = newStatus == 'approved'
          ? 'returned'
          : 'return_rejected';

      await supabase
          .from('orders')
          .update({'status': orderStatus})
          .eq('id', orderId);

      if (mounted) {
        AppNotifications.showSuccess(
          context,
          newStatus == 'approved'
              ? 'Возврат одобрен'
              : 'В возврате официально отказано',
        );
        setState(() {
          _returnsFuture = _fetchReturns();
        });
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка: $e');
    }
  }

  // --- ДИАЛОГ ДЛЯ ВВОДА ПРИЧИНЫ ОТКАЗА ---
  Future<String?> _showRejectReasonDialog() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text(
          'УКАЖИТЕ ПРИЧИНУ ОТКАЗА',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Напр: Следы носки, повреждена упаковка...',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: AdminColors.sidebar,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('ПОДТВЕРДИТЬ ОТКАЗ'),
          ),
        ],
      ),
    );
  }

  void _showReturnDetails(dynamic r) {
    final f = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ДЕТАЛИ ЗАЯВКИ',
                    style: TextStyle(
                      color: AdminColors.accentBlue,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white24),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _dialogRow('Клиент:', r['customer_name']),
              _dialogRow('Сумма заказа:', f.format(r['order_amount'])),
              _dialogRow(
                'Дата заявки:',
                DateFormat(
                  'dd.MM.yyyy HH:mm',
                ).format(DateTime.parse(r['created_at']).toLocal()),
              ),

              const Divider(color: Colors.white10, height: 40),

              const Text(
                'ПРИЧИНА ВОЗВРАТА (ОТ КЛИЕНТА):',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AdminColors.sidebar,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  r['reason'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Кнопки действий
              Row(
                children: [
                  // Кнопка ОТКЛОНИТЬ
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Закрываем основное окно
                        final reason = await _showRejectReasonDialog();
                        if (reason != null && reason.isNotEmpty) {
                          _handleReturn(
                            r['id'],
                            r['order_id'],
                            'rejected',
                            adminComment: reason,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: const Text(
                        'ОТКЛОНИТЬ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Кнопка ОДОБРИТЬ
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleReturn(r['id'], r['order_id'], 'approved');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ОДОБРИТЬ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      context.push('/admin/orders/${r['order_id']}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white38,
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: const Text('ПЕРЕЙТИ В КАРТОЧКУ ЗАКАЗА'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (Методы _dialogRow, build и _actionBtn остаются как были...)
  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
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
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ЗАЯВКИ НА ВОЗВРАТ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 30),
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
                child: FutureBuilder<List<dynamic>>(
                  future: _returnsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Ошибка: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    final returns = snapshot.data!;
                    if (returns.isEmpty) {
                      return const Center(
                        child: Text(
                          'Новых заявок на возврат нет',
                          style: TextStyle(color: Colors.white24),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: DataTable(
                        showCheckboxColumn: false,
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
                          DataColumn(label: Text('КЛИЕНТ')),
                          DataColumn(label: Text('СУММА')),
                          DataColumn(label: Text('ПРИЧИНА')),
                          DataColumn(label: Text('ДЕЙСТВИЯ')),
                        ],
                        rows: returns
                            .map(
                              (r) => DataRow(
                                onSelectChanged: (_) => _showReturnDetails(r),
                                cells: [
                                  DataCell(
                                    Text(r['customer_name'] ?? 'Неизвестный'),
                                  ),
                                  DataCell(Text(f.format(r['order_amount']))),
                                  DataCell(
                                    SizedBox(
                                      width: 250,
                                      child: Text(
                                        r['reason'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        _actionBtn(
                                          Icons.info_outline_rounded,
                                          AdminColors.accentBlue,
                                          () => _showReturnDetails(r),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
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

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
