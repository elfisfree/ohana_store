// lib/features/admin/admin_users_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/admin_user_model.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final ScrollController _scrollController = ScrollController();
  List<AdminUser> _allUsers = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasNextPage = true;
  final int _pageSize = 20;
  String _searchQuery = '';
  String _selectedRole = 'all';
  RangeValues _ageRange = const RangeValues(0, 100);
  final double _minYear = 2024;
  final double _maxYear = DateTime.now().year.toDouble();
  late RangeValues _yearRange;
  bool _isFilterVisible = true;

  @override
  void initState() {
    super.initState();
    _yearRange = RangeValues(_minYear, _maxYear);
    _loadInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isFetchingMore && _hasNextPage) {
          _fetchMoreUsers();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _allUsers = [];
      _hasNextPage = true;
    });
    await _fetchMoreUsers();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchMoreUsers() async {
    if (_isFetchingMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final int from = _allUsers.length;
      final int to = from + _pageSize - 1;
      var query = supabase.from('admin_users_view').select();
      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'first_name.ilike.%$_searchQuery%,last_name.ilike.%$_searchQuery%,email.ilike.%$_searchQuery%',
        );
      }
      if (_selectedRole != 'all') {
        query = query.eq('role', _selectedRole);
      }
      final response = await query
          .range(from, to)
          .order('created_at', ascending: false);

      final newUsers = (response as List)
          .map((u) => AdminUser.fromJson(u))
          .toList();

      if (mounted) {
        setState(() {
          _allUsers.addAll(newUsers);
          _isFetchingMore = false;
          if (newUsers.length < _pageSize) {
            _hasNextPage = false;
          }
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
      setState(() => _isFetchingMore = false);
    }
  }

  void _onFilterChanged() {
    _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'БАЗА КЛИЕНТОВ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Загружено: ${_allUsers.length}',
                      style: const TextStyle(
                        color: AdminColors.accentBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _isFilterVisible
                        ? Icons.filter_list_off
                        : Icons.filter_list,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      setState(() => _isFilterVisible = !_isFilterVisible),
                ),
              ],
            ),
            const SizedBox(height: 25),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                _allUsers.length + (_hasNextPage ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _allUsers.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              return _buildUserCard(_allUsers[index]);
                            },
                          ),
                  ),
                  if (_isFilterVisible) ...[
                    const SizedBox(width: 30),
                    SizedBox(
                      width: 300,
                      child: SingleChildScrollView(child: _buildFilterCard()),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ПОИСК И ФИЛЬТРЫ',
            style: TextStyle(
              color: AdminColors.accentBlue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (val) {
              _searchQuery = val;
              _onFilterChanged();
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Имя или email...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: AdminColors.sidebar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'РОЛЬ',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _roleChip('Все', 'all'),
              _roleChip('Клиент', 'user'),
              _roleChip('Админ', 'admin'),
            ],
          ),
          const SizedBox(height: 25),
          _buildSliderLabel(
            'ВОЗРАСТ',
            '${_ageRange.start.toInt()} - ${_ageRange.end.toInt()}',
          ),
          RangeSlider(
            values: _ageRange,
            min: 0,
            max: 100,
            activeColor: AdminColors.accentBlue,
            onChanged: (val) {
              setState(() => _ageRange = val);
              _onFilterChanged();
            },
          ),
          const SizedBox(height: 20),
          _buildSliderLabel(
            'ГОД РЕГИСТРАЦИИ',
            '${_yearRange.start.toInt()} - ${_yearRange.end.toInt()}',
          ),
          RangeSlider(
            values: _yearRange,
            min: _minYear,
            max: _maxYear,
            activeColor: AdminColors.accentBlue,
            onChanged: (val) {
              setState(() => _yearRange = val);
              _onFilterChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(AdminUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: () => context.push('/admin/users/${user.id}', extra: user),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: AdminColors.sidebar,
          backgroundImage:
              (user.avatarUrl != null && user.avatarUrl!.startsWith('http'))
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: (user.avatarUrl == null || !user.avatarUrl!.startsWith('http'))
              ? const Icon(Icons.person, color: Colors.white24)
              : null,
        ),
        title: Text(
          '${user.firstName} ${user.lastName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          user.email,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AdminColors.sidebar,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            user.role.toUpperCase(),
            style: const TextStyle(
              color: AdminColors.accentBlue,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderLabel(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _roleChip(String label, String value) {
    final bool isSelected = _selectedRole == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedRole = value);
          _onFilterChanged();
        }
      },
      selectedColor: AdminColors.accentBlue,
      backgroundColor: AdminColors.sidebar,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white38,
        fontWeight: FontWeight.bold,
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
