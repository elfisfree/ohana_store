// lib/features/profile/profile_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ohana_store/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? get profileData => _profileData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? get userEmail => supabase.auth.currentUser?.email;

  ProfileProvider() {
    supabase.auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;
      if (session != null) {
        fetchProfile();
      } else {
        _profileData = null;
        notifyListeners();
      }
    });
  }

  Future<void> fetchProfile() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      _profileData = data;
    } catch (e) {
      print('Ошибка при загрузке профиля: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadAvatar(BuildContext context) async {
    if (_isLoading) return;

    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
    );

    if (imageFile == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final file = File(imageFile.path);
      final userId = supabase.auth.currentUser!.id;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';
      final filePath = '$userId/$fileName';
      print('--- Пытаюсь загрузить файл в Storage по пути: $filePath ---');
      await supabase.storage.from('profile-avatars').upload(filePath, file);
      print('--- Файл успешно загружен в Storage ---');
      final imageUrl = supabase.storage
          .from('profile-avatars')
          .getPublicUrl(filePath);
      print('--- Получен публичный URL: $imageUrl ---');
      print('--- Пытаюсь обновить профиль в базе данных ---');
      await supabase
          .from('profiles')
          .update({'avatar_url': imageUrl})
          .eq('id', userId);
      print('--- Профиль в базе данных успешно обновлен ---');

      _profileData?['avatar_url'] = imageUrl;

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Аватар обновлен!')));
      }
    } on StorageException catch (e) {
      print('!!! ОШИБКА STORAGE !!!');
      print('Сообщение: ${e.message}');
      print('Код статуса: ${e.statusCode}');
      print('Ошибка: ${e.error}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка хранилища: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on PostgrestException catch (e) {
      print('!!! ОШИБКА DATABASE !!!');
      print('Сообщение: ${e.message}');
      print('Код: ${e.code}');
      print('Детали: ${e.details}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка базы данных: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('!!! НЕИЗВЕСТНАЯ ОШИБКА !!!');
      print(e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Произошла непредвиденная ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
