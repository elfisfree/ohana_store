import 'package:flutter/material.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';

class MockPaymentPage extends StatefulWidget {
  final String orderId;
  final double amount;

  const MockPaymentPage({
    super.key,
    required this.orderId,
    required this.amount,
  });

  @override
  State<MockPaymentPage> createState() => _MockPaymentPageState();
}

class _MockPaymentPageState extends State<MockPaymentPage> {
  bool _isProcessing = false;

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));

    try {
      await supabase
          .from('orders')
          .update({'payment_status': 'succeeded'})
          .eq('id', widget.orderId);

      if (mounted) {
        AppNotifications.showSuccess(context, 'Оплата прошла успешно!');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка оплаты: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ТЕСТОВАЯ ОПЛАТА ')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              'Сумма к оплате: ${widget.amount.toInt()} ₽',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Заказ №${widget.orderId.substring(0, 8)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 20,
                  ),
                ),
                child: const Text(
                  'ОПЛАТИТЬ (ИМИТАЦИЯ)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
