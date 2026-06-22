// lib/features/admin/admin_reviews_page.dart
// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/admin_review.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});
  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  late Future<List<AdminReview>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _fetchPendingReviews();
  }

  Future<List<AdminReview>> _fetchPendingReviews() async {
    try {
      final response = await supabase
          .from('product_reviews')
          .select('''
            *, 
            products(id, name, materials(name)), 
            order_items!product_reviews_order_item_id_fkey(size, orders(id, final_price, status))
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      return response.map((r) => AdminReview.fromJson(r)).toList();
    } catch (e) {
      print('!!! ОШИБКА ЗАГРУЗКИ ОТЗЫВОВ: $e');
      throw Exception('Не удалось загрузить отзывы');
    }
  }

  Future<void> _moderateReview(String reviewId, String newStatus) async {
    try {
      await supabase
          .from('product_reviews')
          .update({'status': newStatus})
          .eq('id', reviewId);
      if (mounted) {
        AppNotifications.showSuccess(
          context,
          newStatus == 'approved' ? 'Отзыв одобрен' : 'Отзыв отклонен',
        );
        setState(() {
          _reviewsFuture = _fetchPendingReviews();
        });
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'МОДЕРАЦИЯ КОНТЕНТА',
              style: TextStyle(
                color: AdminColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Список новых отзывов, ожидающих проверки перед публикацией.',
              style: TextStyle(color: AdminColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: FutureBuilder<List<AdminReview>>(
                future: _reviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AdminColors.accentPurple,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Ошибка: ${snapshot.error}',
                        style: const TextStyle(color: AdminColors.textPrimary),
                      ),
                    );
                  }

                  final reviews = snapshot.data!;
                  if (reviews.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            size: 60,
                            color: Colors.white10,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Нет новых отзывов для проверки',
                            style: TextStyle(
                              color: AdminColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      final f = NumberFormat.currency(
                        locale: 'ru_RU',
                        symbol: '₽',
                        decimalDigits: 0,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AdminColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 5,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AdminColors.accentPurple.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AdminColors.accentPurple,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                review.productName,
                                style: const TextStyle(
                                  color: AdminColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: const Text(
                                'Посмотреть товар на витрине',
                                style: TextStyle(
                                  color: AdminColors.accentPurple,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () =>
                                  context.push('/product/${review.productId}'),
                              trailing: Text(
                                DateFormat(
                                  'dd.MM.yyyy HH:mm',
                                ).format(review.createdAt.toLocal()),
                                style: const TextStyle(
                                  color: AdminColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: Colors.white10),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _infoBadge(
                                        Icons.straighten,
                                        'Размер: ${review.orderedSize}',
                                        Colors.orangeAccent,
                                      ),
                                      const SizedBox(width: 10),
                                      _infoBadge(
                                        Icons.layers_outlined,
                                        'Материал: ${review.materialName}',
                                        Colors.blueGrey,
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Заказ №${review.orderId.substring(0, 8)}',
                                        style: const TextStyle(
                                          color: AdminColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AdminColors.sidebar,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.black.withValues(
                                          alpha: 0.03,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      review.reviewText.isNotEmpty
                                          ? review.reviewText
                                          : 'Пользователь не оставил текстового описания, только оценку.',
                                      style: TextStyle(
                                        color: review.reviewText.isNotEmpty
                                            ? Colors.white
                                            : Colors.white24,
                                        fontSize: 15,
                                        fontStyle: review.reviewText.isNotEmpty
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 25),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _moderateReview(
                                          review.id,
                                          'rejected',
                                        ),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('ОТКЛОНИТЬ'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      ElevatedButton.icon(
                                        onPressed: () => _moderateReview(
                                          review.id,
                                          'approved',
                                        ),
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('ОДОБРИТЬ ОТЗЫВ'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.05),
                                          foregroundColor: Colors.greenAccent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 25,
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: const BorderSide(
                                              color: Colors.greenAccent,
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
