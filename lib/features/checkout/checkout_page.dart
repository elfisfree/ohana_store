// lib/features/checkout/checkout_page.dart
// ignore_for_file: use_build_context_synchronously, unused_field, unused_element_parameter

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/services/connectivity_service.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/features/checkout/mock_payment_page.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/cart_item.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/features/cart/cart_provider.dart';
import 'package:ohana_store/models/product.dart';
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

// ignore: constant_identifier_names
enum PaymentMethod { online, on_delivery }

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

  bool _withFitting = false;

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

      final allowedTypeIds = List<String>.from(
        response['applicable_product_type_ids'] ?? [],
      );
      if (allowedTypeIds.isNotEmpty) {
        final hasEligibleItems = _selectedItems.any(
          (item) => allowedTypeIds.contains(item.product.productType?.id),
        );

        if (!hasEligibleItems) {
          throw Exception('Этот промокод не применим к выбранным вами товарам');
        }
      }

      setState(() {
        _appliedPromocode = AppliedPromocode(
          id: response['id'],
          discountPercentage: (response['discount_percentage'] as num)
              .toDouble(),
          applicableProductTypeIds: allowedTypeIds,
        );
        _calculateTotals();
      });

      if (mounted) {
        AppNotifications.showSuccess(
          context,
          'Промокод применен к подходящим товарам!',
        );
      }
    } catch (e) {
      setState(() {
        _appliedPromocode = null;
        _calculateTotals();
      });
      if (mounted) {
        AppNotifications.showError(
          context,
          e.toString().replaceFirst("Exception: ", ""),
        );
      }
    } finally {
      if (mounted) setState(() => _isPromocodeLoading = false);
    }
  }

  Future<void> _fetchInitialData({bool selectLastAddress = false}) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final results = await Future.wait([
        supabase
            .from('cart_items')
            .select(
              '*, products(*, brands(*), product_types(*)), product_variants(*, product_stock(*))',
            )
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
      print("Ошибка в полуении информации о продукте: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateItemQuantity(CartItem item, int newQuantity) async {
    if (newQuantity < 1) return;
    if (newQuantity > item.quantity) {
      final stock = item.variant?.stock.firstWhere(
        (s) => s.size == item.size,
        orElse: () => StockItem(id: '', size: 0, quantity: 0),
      );
      if (stock != null && newQuantity > stock.quantity) {
        AppNotifications.showError(context, 'Больше нет в наличии');
        return;
      }
    }
    await context.read<CartProvider>().updateQuantity(item.id, newQuantity);
    setState(() {
      final index = _selectedItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _selectedItems[index] = CartItem(
          id: item.id,
          quantity: newQuantity,
          size: item.size,
          product: item.product,
          variant: item.variant,
        );
        _calculateTotals();
      }
    });
  }

  Future<void> _showAddAddressDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddressFormDialog(),
    );

    if (result != null && mounted) {
      try {
        await supabase.from('user_addresses').insert({
          'user_id': supabase.auth.currentUser!.id,
          'name': result['name'],
          'city': result['city'],
          'street': result['street'],
          'house': result['house'],
          'floor': result['floor'],
          'apartment': result['apartment'],
        });
        await _fetchInitialData(selectLastAddress: true);

        AppNotifications.showSuccess(context, 'Адрес добавлен');
      } catch (e) {
        AppNotifications.showError(context, 'Ошибка сохранения адреса: $e');
      }
    } else {
      setState(
        () => _selectedAddressId = _userAddresses.isNotEmpty
            ? _userAddresses.first.id
            : null,
      );
    }
  }

  void _calculateTotals() {
    _subtotal = _selectedItems.fold(
      0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );

    _discountAmount = 0.0;

    if (_appliedPromocode != null) {
      double eligibleAmount = 0.0;
      if (_appliedPromocode!.applicableProductTypeIds.isEmpty) {
        eligibleAmount = _subtotal;
      } else {
        for (var item in _selectedItems) {
          if (_appliedPromocode!.applicableProductTypeIds.contains(
            item.product.productType?.id,
          )) {
            eligibleAmount += (item.product.price * item.quantity);
          }
        }
      }
      _discountAmount =
          eligibleAmount * (_appliedPromocode!.discountPercentage / 100);
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
          .fullAddress;
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
          'p_with_fitting': _withFitting,
          'p_payment_method': _paymentMethod.name,
        },
      );
      if (mounted) {
        final cartProvider = context.read<CartProvider>();
        cartProvider.clearOrderedItems(widget.selectedCartItemIds.toList());
        await cartProvider.fetchCartItems();
      }

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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Сама карточка выбора
                              InkWell(
                                onTap:
                                    _showAddressPickerSheet, // Метод для открытия шторки
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _selectedAddressId == null
                                          ? Colors.red.withValues(alpha: 0.5)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedAddressId == null
                                                  ? 'ВЫБРАТЬ АДРЕС'
                                                  : _userAddresses
                                                            .firstWhere(
                                                              (a) =>
                                                                  a.id ==
                                                                  _selectedAddressId,
                                                            )
                                                            .name
                                                            ?.toUpperCase() ??
                                                        'АДРЕС',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            if (_selectedAddressId != null)
                                              Text(
                                                _userAddresses
                                                    .firstWhere(
                                                      (a) =>
                                                          a.id ==
                                                          _selectedAddressId,
                                                    )
                                                    .fullAddress,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_right,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Маленькая подсказка об ошибке, если адрес не выбран
                              if (_selectedAddressId == null)
                                const Padding(
                                  padding: EdgeInsets.only(left: 12, top: 4),
                                  child: Text(
                                    'Пожалуйста, выберите адрес доставки',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 30),

                      _buildSectionTitle('Дополнительные услуги'),
                      const SizedBox(height: 10),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SwitchListTile(
                          secondary: const Icon(
                            Icons.checkroom_outlined,
                            color: Colors.black,
                          ),
                          title: const Text(
                            'Примерка перед покупкой',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Примерка товаров перед покупкой',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: _withFitting,
                          activeColor: Colors.black,
                          onChanged: (val) =>
                              setState(() => _withFitting = val),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                              subtitle: const Text('Тестовая оплата'),
                              value: PaymentMethod.online, // Значение из Enum
                              groupValue: _paymentMethod,
                              activeColor: Colors.black,
                              onChanged: (val) =>
                                  setState(() => _paymentMethod = val!),
                            ),
                            const Divider(height: 1, indent: 20, endIndent: 20),
                            RadioListTile<PaymentMethod>(
                              title: const Text(
                                'Оплата при получении',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'Наличными или картой после примерки',
                              ),
                              value: PaymentMethod.on_delivery,
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

  void _showAddressPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          // Используем для мгновенного обновления внутри шторки
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'КУДА ДОСТАВИТЬ?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 20),

                  // Список адресов
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _userAddresses.length,
                      itemBuilder: (context, index) {
                        final addr = _userAddresses[index];
                        final isSelected = _selectedAddressId == addr.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedAddressId = addr.id);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black.withValues(alpha: 0.03)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          addr.name ?? 'Адрес ${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          addr.fullAddress,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(height: 30),

                  // Кнопка добавления нового
                  ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      _showAddAddressDialog();
                    },
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.black,
                    ),
                    title: const Text(
                      'ДОБАВИТЬ НОВЫЙ АДРЕС',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
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
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      )
                    : Container(width: 60, height: 60, color: Colors.grey[200]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Размер: ${item.size.toInt()} | ${item.variant?.colorName ?? "Стандарт"}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                f.format(item.product.price * item.quantity),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'КОЛИЧЕСТВО',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black38,
                ),
              ),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      onPressed: item.quantity > 1
                          ? () => _updateItemQuantity(item, item.quantity - 1)
                          : null,
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () =>
                          _updateItemQuantity(item, item.quantity + 1),
                    ),
                  ],
                ),
              ),
            ],
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
    final isOnline = context.watch<ConnectivityService>().isConnected;

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
              onPressed: (_isConfirming || !isOnline) ? null : _confirmOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOnline ? Colors.white : Colors.grey.shade800,
                foregroundColor: isOnline ? Colors.black : Colors.white24,
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
                  : Text(
                      isOnline ? 'Подтвердить заказ' : 'ЖДЕМ СЕТЬ...',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 0.5,
                        color: isOnline ? Colors.black : Colors.white24,
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

class _AddressFormDialog extends StatefulWidget {
  final UserAddress? address;
  const _AddressFormDialog({this.address});

  @override
  State<_AddressFormDialog> createState() => __AddressFormDialogState();
}

class __AddressFormDialogState extends State<_AddressFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _streetController;
  late final TextEditingController _houseController;
  late final TextEditingController _floorController;
  late final TextEditingController _aptController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.address?.name ?? 'Дом',
    );
    _cityController = TextEditingController(
      text: widget.address?.city ?? 'Казань',
    );
    _streetController = TextEditingController(
      text: widget.address?.street ?? '',
    );
    _houseController = TextEditingController(text: widget.address?.house ?? '');
    _floorController = TextEditingController(text: widget.address?.floor ?? '');
    _aptController = TextEditingController(
      text: widget.address?.apartment ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _houseController.dispose();
    _floorController.dispose();
    _aptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450), // Для десктопа
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ЗАГОЛОВОК
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.address == null ? 'НОВЫЙ АДРЕС' : 'РЕДАКТИРОВАНИЕ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ПОЛЕ: НАЗВАНИЕ (Дом/Работа)
                _buildModernField(
                  controller: _nameController,
                  label: 'Название',
                  hint: 'Например: Дом, Офис, Дача',
                  icon: Icons.bookmark_outline,
                  isRequired: true,
                ),
                const SizedBox(height: 16),

                // ПОЛЕ: ГОРОД
                _buildModernField(
                  controller: _cityController,
                  label: 'Город',
                  icon: Icons.location_city_outlined,
                  isRequired: true,
                ),
                const SizedBox(height: 16),

                // ПОЛЕ: УЛИЦА
                _buildModernField(
                  controller: _streetController,
                  label: 'Улица',
                  icon: Icons.add_location_outlined,
                  isRequired: true,
                ),
                const SizedBox(height: 16),

                // РЯД: ДОМ, ЭТАЖ, КВАРТИРА
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildModernField(
                        controller: _houseController,
                        label: 'Дом',
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildModernField(
                        controller: _floorController,
                        label: 'Этаж',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildModernField(
                        controller: _aptController,
                        label: 'Кв/Офис',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // КНОПКА СОХРАНЕНИЯ
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.pop(context, {
                          'name': _nameController.text.trim(),
                          'city': _cityController.text.trim(),
                          'street': _streetController.text.trim(),
                          'house': _houseController.text.trim(),
                          'floor': _floorController.text.trim(),
                          'apartment': _aptController.text.trim(),
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'СОХРАНИТЬ АДРЕС',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // МЕТОД ДЛЯ СОЗДАНИЯ КРАСИВОГО ПОЛЯ
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool isRequired = false,
    bool isReadOnly = false, // Новый параметр
    String? helperText, // Новый параметр
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: isReadOnly, // ПРИМЕНЯЕМ: запрет редактирования
          validator: isRequired && !isReadOnly
              ? (v) => v!.trim().isEmpty ? '!' : null
              : null,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            // Если поле только для чтения, делаем текст чуть тусклее
            color: isReadOnly ? Colors.grey.shade600 : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            // ПРИМЕНЯЕМ: Настройка подсказки (например, про Казань)
            helperText: helperText,
            helperStyle: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: icon != null
                ? Icon(
                    icon,
                    size: 20,
                    color: isReadOnly ? Colors.grey : Colors.black87,
                  )
                : null,
            filled: true,
            fillColor: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isReadOnly ? Colors.transparent : Colors.black,
                width: 1.5,
              ),
            ),
            errorStyle: const TextStyle(height: 0),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
