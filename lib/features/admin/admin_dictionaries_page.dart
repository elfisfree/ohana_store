// lib/features/admin/admin_dictionaries_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';

class AdminDictionariesPage extends StatefulWidget {
  const AdminDictionariesPage({super.key});

  @override
  State<AdminDictionariesPage> createState() => _AdminDictionariesPageState();
}

class _AdminDictionariesPageState extends State<AdminDictionariesPage> {
  // Список сущностей для вкладок
  final List<Map<String, String>> _configs = [
    {'title': 'БРЕНДЫ', 'table': 'brands', 'type': 'brand'},
    {'title': 'КАТЕГОРИИ', 'table': 'product_types', 'type': 'type'},
    {'title': 'СТИЛИ', 'table': 'styles', 'type': 'style'},
    {'title': 'МАТЕРИАЛЫ', 'table': 'materials', 'type': 'material'},
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _configs.length,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'УПРАВЛЕНИЕ СПРАВОЧНИКАМИ',
            style: TextStyle(
              color: AdminColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabBarIndicatorSize.label == TabBarIndicatorSize.label
                ? TabAlignment.start
                : null,
            indicatorColor: AdminColors.accentPurple,
            labelColor: AdminColors.accentPurple,
            unselectedLabelColor: AdminColors.textPrimary,
            tabs: _configs.map((c) => Tab(text: c['title'])).toList(),
          ),
        ),
        body: TabBarView(
          children: _configs
              .map(
                (c) => _DictionaryTable(
                  tableName: c['table']!,
                  entityType: c['type']!,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _DictionaryTable extends StatefulWidget {
  final String tableName;
  final String entityType;
  const _DictionaryTable({required this.tableName, required this.entityType});

  @override
  State<_DictionaryTable> createState() => _DictionaryTableState();
}

class _DictionaryTableState extends State<_DictionaryTable> {
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _dataFuture = supabase
          .from('dictionary_analytics_view')
          .select()
          .eq('entity_type', widget.entityType)
          .order('name');
    });
  }

  void _showUpsertDialog([Map<String, dynamic>? item]) {
    final controller = TextEditingController(text: item?['name'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: Text(
          item == null ? 'НОВАЯ ЗАПИСЬ' : 'ПРАВКА',
          style: const TextStyle(color: AdminColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AdminColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AdminColors.sidebar,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              try {
                if (item == null) {
                  await supabase.from(widget.tableName).insert({
                    'name': controller.text.trim(),
                  });
                } else {
                  await supabase
                      .from(widget.tableName)
                      .update({'name': controller.text.trim()})
                      .eq('id', item['id']);
                }
                Navigator.pop(ctx);
                AppNotifications.showSuccess(context, 'Сохранено');
                _refresh();
              } catch (e) {
                AppNotifications.showError(context, 'Ошибка: $e');
              }
            },
            child: const Text('СОХРАНИТЬ'),
          ),
        ],
      ),
    );
  }

  // --- УДАЛЕНИЕ ---
  void _deleteItem(Map<String, dynamic> item) async {
    if (item['usage_count'] > 0) {
      AppNotifications.showError(
        context,
        'Нельзя удалить: этот элемент используют ${item['usage_count']} товаров',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text(
          'УДАЛИТЬ?',
          style: TextStyle(color: AdminColors.textPrimary),
        ),
        content: Text('Вы уверены, что хотите удалить "${item['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('НЕТ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.from(widget.tableName).delete().eq('id', item['id']);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _showUpsertDialog(),
              icon: const Icon(Icons.add),
              label: const Text('ДОБАВИТЬ'),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AdminColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: FutureBuilder<List<dynamic>>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!;
                  return SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('НАЗВАНИЕ')),
                        DataColumn(label: Text('ТОВАРОВ В БАЗЕ')),
                        DataColumn(label: Text('ДЕЙСТВИЯ')),
                      ],
                      rows: items
                          .map(
                            (item) => DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    item['name'],
                                    style: const TextStyle(
                                      color: AdminColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item['usage_count'].toString(),
                                    style: TextStyle(
                                      color: item['usage_count'] > 0
                                          ? AdminColors.textPrimary
                                          : AdminColors.textSecondary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: AdminColors.textPrimary,
                                          size: 18,
                                        ),
                                        onPressed: () =>
                                            _showUpsertDialog(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                          size: 18,
                                        ),
                                        onPressed: () => _deleteItem(item),
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
    );
  }
}
