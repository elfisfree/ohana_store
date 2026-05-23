// lib/features/checkout/checkout_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/features/checkout/mock_payment_page.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/cart_item.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/features/cart/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:ohana_store/models/user_address.dart';

class AppliedPromocode {
  final String id;
  final double discountPercentage;
  final List<String> applicableProductTypeIds;
  AppliedPromocode({
    required this.id,
    required this.discountPercentage,
    required this.applicableProductTypeIds,
  });
}

enum DeliveryMethod { courier, pickup }

enum PaymentMethod { online, cash }

class CheckoutPage extends StatefulWidget {
  final Set<String> selectedCartItemIds;
  const CheckoutPage({super.key, required this.selectedCartItemIds});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _promocodeController = TextEditingController();
  AppliedPromocode? _appliedPromocode;
  double _discountAmount = 0.0;
  bool _isPromocodeLoading = false;
  bool _isLoading = true;
  String? _error;
  List<CartItem> _selectedItems = [];
  PaymentMethod _paymentMethod = PaymentMethod.online;

  DeliveryMethod _deliveryMethod = DeliveryMethod.pickup;
  final _addressController = TextEditingController();

  List<UserAddress> _userAddresses = [];
  String? _selectedAddressId;
  bool _isConfirming = false;

  double _subtotal = 0.0;
  double _deliveryCost = 300.0;
  double _totalPrice = 0.0;

  static const String pickupAddress =
      'пр-т. Победы, 141, Казань, Респ. Татарстан, Россия';
  static const double deliveryPrice = 300.0;

  static const String _addNewAddressValue = 'ADD_NEW_ADDRESS';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _promocodeController.dispose();
    super.dispose();
  }

  Future<void> _applyPromocode() async {
    final code = _promocodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isPromocodeLoading = true);

    try {
      final response = await supabase.rpc(
        'validate_promocode',
        params: {'p_code': code, 'p_order_amount': _subtotal},
      );

      if (response['error'] != null) {
        throw Exception(response['error']);
      }
      setState(() {
        _appliedPromocode = AppliedPromocode(
          id: response['id'],
          discountPercentage: (response['discount_percentage'] as num)
              .toDouble(),
          applicableProductTypeIds: List<String>.from(
            response['applicable_product_type_ids'] ?? [],
          ),
        );
        _calculateTotals();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Промокод применен!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _appliedPromocode = null;
        _calculateTotals();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ошибка: ${e.toString().replaceFirst("Exception: ", "")}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isPromocodeLoading = false);
    }
  }

  Future<void> _fetchInitialData({bool selectLastAddress = false}) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final results = await Future.wait([
        supabase
            .from('cart_items')
            .select('*, products(*, brands(*))')
            .inFilter('id', widget.selectedCartItemIds.toList()),
        supabase
            .from('user_addresses')
            .select()
            .eq('user_id', userId)
            .order('created_at'),
      ]);

      final items = (results[0] as List)
          .map((item) => CartItem.fromJson(item))
          .toList();
      final addresses = (results[1] as List)
          .map((addr) => UserAddress.fromJson(addr))
          .toList();

      if (mounted) {
        setState(() {
          _selectedItems = items;
          _userAddresses = addresses;
          if (_userAddresses.isNotEmpty) {
            _selectedAddressId = selectLastAddress
                ? _userAddresses.last.id
                : _userAddresses.first.id;
          }
          _calculateTotals();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить данные';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddAddressDialog() async {
    final newAddress = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddAddressDialog(),
    );

    if (newAddress != null && mounted) {
      try {
        await supabase.from('user_addresses').insert({
          'user_id': supabase.auth.currentUser!.id,
          'name': newAddress['name'],
          'address_line': newAddress['address'],
        });
        await _fetchInitialData(selectLastAddress: true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateTotals() {
    _subtotal = _selectedItems.fold(
      0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );

    _discountAmount = 0.0;
    if (_appliedPromocode != null) {
      double amountToDiscount = _subtotal;

      if (_appliedPromocode!.applicableProductTypeIds.isNotEmpty) {
        amountToDiscount = _selectedItems
            .where(
              (item) => _appliedPromocode!.applicableProductTypeIds.contains(
                item.product.productType?.id,
              ),
            )
            .fold(0, (sum, item) => sum + (item.product.price * item.quantity));
      }

      _discountAmount =
          amountToDiscount * (_appliedPromocode!.discountPercentage / 100);
    }

    _deliveryCost = _deliveryMethod == DeliveryMethod.courier ? 300.0 : 0.0;
    _totalPrice = _subtotal - _discountAmount + _deliveryCost;
  }

  void _onDeliveryMethodChanged(DeliveryMethod? value) {
    if (value != null) {
      setState(() {
        _deliveryMethod = value;
        _calculateTotals();
      });
    }
  }

  Future<void> _confirmOrder() async {
    String? finalShippingAddress;
    if (_deliveryMethod == DeliveryMethod.courier) {
      if (_selectedAddressId == null) {
        AppNotifications.showError(context, 'Выберите адрес доставки');
        return;
      }
      finalShippingAddress = _userAddresses
          .firstWhere((addr) => addr.id == _selectedAddressId)
          .addressLine;
    }

    setState(() => _isConfirming = true);

    try {
      final newOrderId = await supabase.rpc(
        'create_order_from_cart',
        params: {
          'selected_cart_ids': widget.selectedCartItemIds.toList(),
          'p_delivery_method': _deliveryMethod.name,
          'p_shipping_address': finalShippingAddress,
          'p_promocode_id': _appliedPromocode?.id,
        },
      );
      await context.read<CartProvider>().fetchCartItems();

      if (!mounted) return;
      if (_paymentMethod == PaymentMethod.online) {
        // ignore: unused_local_variable
        final bool? paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MockPaymentPage(
              orderId: newOrderId as String,
              amount: _totalPrice,
            ),
          ),
        );
        if (mounted) {
          context.go('/order-success/$newOrderId');
        }
      } else {
        context.go('/order-success/$newOrderId');
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isConfirming = false);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Оформление',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Ошибка: $_error'))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSectionTitle('Ваш заказ'),
                      const SizedBox(height: 10),
                      ..._selectedItems.map((item) => _buildItemTile(item, f)),
                      const SizedBox(height: 30),

                      _buildSectionTitle('Промокод'),
                      const SizedBox(height: 10),
                      _buildPromoInput(),

                      const SizedBox(height: 30),
                      _buildSectionTitle('Доставка'),
                      const SizedBox(height: 10),
                      _buildDeliverySelector(f),

                      if (_deliveryMethod == DeliveryMethod.courier)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: DropdownButtonFormField<String>(
                            value: _selectedAddressId,
                            decoration: _inputDecoration(
                              'Выберите адрес доставки',
                            ),
                            isExpanded: true,
                            items: [
                              ..._userAddresses.map(
                                (addr) => DropdownMenuItem(
                                  value: addr.id,
                                  child: Text(
                                    '${addr.name} (${addr.addressLine})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: _addNewAddressValue,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Добавить новый адрес...'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == _addNewAddressValue) {
                                _showAddAddressDialog();
                              } else {
                                setState(() => _selectedAddressId = value);
                              }
                            },
                            validator: (value) => value == null
                                ? 'Выберите или добавьте адрес'
                                : null,
                          ),
                        ),
                      const SizedBox(height: 30),
                      _buildSectionTitle('Способ оплаты'),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<PaymentMethod>(
                              title: const Text(
                                'Картой онлайн',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text('Тестовая оплата ЮKassa'),
                              value: PaymentMethod.online,
                              groupValue: _paymentMethod,
                              activeColor: Colors.black,
                              onChanged: (val) =>
                                  setState(() => _paymentMethod = val!),
                            ),
                            const Divider(height: 1, indent: 20, endIndent: 20),
                            RadioListTile<PaymentMethod>(
                              title: const Text(
                                'При получении',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'Наличными или картой курьеру',
                              ),
                              value: PaymentMethod.cash,
                              groupValue: _paymentMethod,
                              activeColor: Colors.black,
                              onChanged: (val) =>
                                  setState(() => _paymentMethod = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                _buildBottomSummary(f),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildItemTile(CartItem item, NumberFormat f) {
    String imageUrl = "";
    if (item.variant != null && item.variant!.imageUrls.isNotEmpty) {
      imageUrl = item.variant!.imageUrls.first;
    } else if (item.product.variants.isNotEmpty &&
        item.product.variants.first.imageUrls.isNotEmpty) {
      imageUrl = item.product.variants.first.imageUrls.first;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image_not_supported),
                  )
                : Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Цвет: ${item.variant?.colorName ?? "Стандарт"}, Размер: ${item.size.toInt()}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            f.format(item.product.price),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoInput() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _promocodeController,
            decoration: _inputDecoration('Введите промокод'),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _isPromocodeLoading ? null : _applyPromocode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isPromocodeLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildDeliverySelector(NumberFormat f) {
    return Column(
      children: [
        _deliveryOption(
          title: 'Доставка курьером',
          subtitle: '+ ${f.format(deliveryPrice)}',
          value: DeliveryMethod.courier,
        ),
        const SizedBox(height: 10),
        _deliveryOption(
          title: 'Самовывоз',
          subtitle: pickupAddress,
          value: DeliveryMethod.pickup,
        ),
      ],
    );
  }

  Widget _deliveryOption({
    required String title,
    required String subtitle,
    required DeliveryMethod value,
  }) {
    return GestureDetector(
      onTap: () => _onDeliveryMethodChanged(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: _deliveryMethod == value
                ? Colors.black
                : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              _deliveryMethod == value
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: Colors.black,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSummary(NumberFormat f) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _summaryRow('Товары', f.format(_subtotal)),
          if (_discountAmount > 0)
            _summaryRow(
              'Скидка',
              '-${f.format(_discountAmount)}',
              valueColor: Colors.greenAccent,
            ),
          _summaryRow('Доставка', f.format(_deliveryCost)),
          const Divider(color: Colors.white24),

          _summaryRow(
            'Итого',
            f.format(_totalPrice),
            isBold: true,
            valueColor: Colors.white,
          ),

          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isConfirming ? null : _confirmOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isConfirming
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Подтвердить заказ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white70,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog();

  @override
  State<_AddAddressDialog> createState() => __AddAddressDialogState();
}

class __AddAddressDialogState extends State<_AddAddressDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый адрес'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название (напр., Дом)',
              ),
              validator: (v) =>
                  v!.trim().isEmpty ? 'Это обязательное поле' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Адрес'),
              validator: (v) =>
                  v!.trim().isEmpty ? 'Это обязательное поле' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'address': _addressController.text.trim(),
              });
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
