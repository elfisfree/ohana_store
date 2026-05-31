// lib/features/profile/edit_profile_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/features/profile/profile_provider.dart';
import 'package:ohana_store/main.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const EditProfilePage({super.key, required this.initialData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _patronymicController;
  late final TextEditingController _dobController;

  String? _selectedGender;
  DateTime? _selectedDob;
  bool _isLoading = false;

  final _phoneFormatter = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _firstNameController = TextEditingController(
      text: data['first_name'] ?? '',
    );
    _lastNameController = TextEditingController(text: data['last_name'] ?? '');
    _patronymicController = TextEditingController(
      text: data['patronymic'] ?? '',
    );
    if (data['date_of_birth'] != null) {
      _selectedDob = DateTime.tryParse(data['date_of_birth']);
    }
    _dobController = TextEditingController(
      text: _selectedDob != null
          ? DateFormat('dd.MM.yyyy').format(_selectedDob!)
          : '',
    );
    _phoneController = TextEditingController(
      text: widget.initialData['phone'] ?? '',
    );
    super.initState();
    _selectedGender = data['gender'];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _patronymicController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('ru', 'RU'),
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  bool _isDataValid() {
    final nameRegExp = RegExp(r'^[a-zA-Zа-яА-ЯёЁ]+$');

    if (_lastNameController.text.trim().isEmpty) {
      AppNotifications.showError(context, 'Введите фамилию');
      return false;
    }
    if (!nameRegExp.hasMatch(_lastNameController.text.trim())) {
      AppNotifications.showError(context, 'В фамилии разрешены только буквы');
      return false;
    }

    if (_firstNameController.text.trim().isEmpty) {
      AppNotifications.showError(context, 'Введите имя');
      return false;
    }
    if (!nameRegExp.hasMatch(_firstNameController.text.trim())) {
      AppNotifications.showError(context, 'В имени разрешены только буквы');
      return false;
    }

    if (_selectedDob != null) {
      final now = DateTime.now();
      int age = now.year - _selectedDob!.year;
      if (now.month < _selectedDob!.month ||
          (now.month == _selectedDob!.month && now.day < _selectedDob!.day)) {
        age--;
      }

      if (age < 12) {
        AppNotifications.showError(context, 'Вам должно быть минимум 12 лет');
        return false;
      }
    } else {
      AppNotifications.showError(context, 'Укажите дату рождения');
      return false;
    }

    return true;
  }

  Future<void> _saveProfile() async {
    if (!_isDataValid()) return;

    if (_phoneController.text.isNotEmpty && !_phoneFormatter.isFill()) {
      AppNotifications.showError(context, 'Введите корректный номер телефона');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updates = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'patronymic': _patronymicController.text.trim(),
        'gender': _selectedGender,
        'date_of_birth': _selectedDob?.toIso8601String(),
        'phone': _phoneController.text.trim(),
      };

      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').update(updates).eq('id', userId);
      await context.read<ProfileProvider>().fetchProfile();

      if (mounted) {
        AppNotifications.showSuccess(context, 'Профиль обновлен');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Ошибка: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'РЕДАКТОР ПРОФИЛЯ',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _title('ЛИЧНАЯ ИНФОРМАЦИЯ'),
                  const SizedBox(height: 20),
                  _customField(
                    controller: _lastNameController,
                    label: 'Фамилия',
                  ),
                  const SizedBox(height: 20),
                  _customField(controller: _firstNameController, label: 'Имя'),
                  const SizedBox(height: 20),
                  _customField(
                    controller: _patronymicController,
                    label: 'Отчество',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _phoneController,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_phoneFormatter],
                    decoration: InputDecoration(
                      labelText: 'ТЕЛЕФОН',
                      hintText: '+7 (___) ___-__-__',
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: _customField(
                        controller: _dobController,
                        label: 'Дата рождения',
                      ),
                    ),
                  ),

                  const SizedBox(height: 35),
                  _title('ПОЛ'),
                  const SizedBox(height: 10),
                  _genderSelector(),
                  const SizedBox(height: 45),
                  _saveButton(),
                ],
              ),
            ),
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _customField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      maxLength: 30,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zа-яА-ЯёЁ. ]')),
      ],
      decoration: InputDecoration(
        counterText: "",
        labelText: label.toUpperCase(),
        labelStyle: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _genderSelector() {
    return Column(
      children: [
        _genderOption("male", "Мужской"),
        const SizedBox(height: 10),
        _genderOption("female", "Женский"),
      ],
    );
  }

  Widget _genderOption(String value, String label) {
    final bool isActive = _selectedGender == value;
    final primaryColor = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withValues(alpha: .1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? primaryColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isActive ? primaryColor : Colors.grey[500],
            ),
            const SizedBox(width: 18),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isActive ? primaryColor : Colors.black,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _saveProfile,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Text(
          'СОХРАНИТЬ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
