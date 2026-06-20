import 'package:flutter/material.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/promocode.dart';

class PromocodesProvider extends ChangeNotifier {
  List<Promocode> _promocodes = [];
  bool _isLoading = false;

  List<Promocode> get promocodes => _promocodes;
  bool get isLoading => _isLoading;

  PromocodesProvider() {
    fetchPromocodes();
  }

  Future<void> fetchPromocodes() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await supabase
          .from('promocodes')
          .select('*, product_types(*)')
          .order('created_at', ascending: false);

      _promocodes = (response as List)
          .map((p) => Promocode.fromJson(p))
          .toList();
    } catch (e) {
      print('Ошибка загрузки промокодов: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deletePromocode(String id) async {
    try {
      await supabase.from('promocodes').delete().eq('id', id);
      await fetchPromocodes(); // Авто-обновление списка после удаления
    } catch (e) {
      rethrow;
    }
  }
}
