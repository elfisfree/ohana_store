// lib/features/orders/add_review_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
// ignore: unused_import
import 'package:go_router/go_router.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';

class AddReviewPage extends StatefulWidget {
  final String orderItemId;
  final String productId;
  const AddReviewPage({
    super.key,
    required this.orderItemId,
    required this.productId,
  });

  @override
  State<AddReviewPage> createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  final _textController = TextEditingController();
  double _rating = 3.0;
  bool _isSaving = false;

  Future<void> _submitReview() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('product_reviews').insert({
        'user_id': userId,
        'product_id': widget.productId,
        'order_item_id': widget.orderItemId,
        'rating': _rating.toInt(),
        'review_text': _textController.text.trim(),
        'status': 'pending',
      });

      if (mounted) {
        AppNotifications.showSuccess(context, 'Отзыв отправлен на модерацию');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(
          context,
          'Вы уже оставили отзыв на этот товар',
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Оставить отзыв',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Оценка товара',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 16),

            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              itemSize: 40,
              unratedColor: Colors.black12,
              itemBuilder: (_, __) =>
                  const Icon(Icons.star_rounded, color: Colors.black),
              onRatingUpdate: (r) => setState(() => _rating = r),
            ),

            const SizedBox(height: 32),

            const Text(
              'Комментарий',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey.shade100,
              ),
              padding: const EdgeInsets.all(12),
              child: TextFormField(
                controller: _textController,
                maxLines: 5,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Напишите, что вам понравилось...',
                  hintStyle: TextStyle(color: Colors.black38),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Опубликовать отзыв',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }
}
