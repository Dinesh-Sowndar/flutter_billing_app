import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/features/product/data/models/category_model.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:uuid/uuid.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();
  String? _editingCategoryId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final box = HiveDatabase.categoryBox;

    if (_editingCategoryId != null) {
      // Edit
      final category = box.values.firstWhere((c) => c.id == _editingCategoryId);
      final index = box.values.toList().indexOf(category);
      if (index != -1) {
        final updated = CategoryModel(
          id: category.id,
          name: name,
          pendingSync: true,
        );
        await box.putAt(index, updated);
      }
    } else {
      // Add
      if (box.length >= 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 8 categories allowed.')),
        );
        return;
      }
      final newCategory = CategoryModel(
        id: _uuid.v4(),
        name: name,
        pendingSync: true,
      );
      await box.add(newCategory);
    }

    _controller.clear();
    setState(() {
      _editingCategoryId = null;
    });
  }

  void _editCategory(CategoryModel category) {
    setState(() {
      _editingCategoryId = category.id;
      _controller.text = category.name;
    });
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final box = HiveDatabase.categoryBox;
    final index = box.values.toList().indexOf(category);
    if (index != -1) {
      // Also unassign this category from all products
      final productBox = HiveDatabase.productBox;
      for (var i = 0; i < productBox.length; i++) {
        final product = productBox.getAt(i);
        if (product != null && product.categoryId == category.id) {
          final updatedPModel = product.toEntity().copyWith(categoryId: null, pendingSync: true);
          final updatedModel = ProductModel.fromEntity(updatedPModel);
          await productBox.putAt(i, updatedModel);
        }
      }
      await box.deleteAt(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Manage Categories',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: HiveDatabase.categoryBox.listenable(),
                builder: (context, box, _) {
                  final categories = box.values.toList();
                  if (categories.isEmpty) {
                    return const Center(
                      child: Text(
                        'No categories added yet.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit_rounded, color: AppTheme.primaryColor),
                                  onPressed: () => _editCategory(category),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  onPressed: () => _deleteCategory(category),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ValueListenableBuilder(
                valueListenable: HiveDatabase.categoryBox.listenable(),
                builder: (context, box, _) {
                  final isAtLimit = box.length >= 8;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              enabled: _editingCategoryId != null || !isAtLimit,
                              decoration: InputDecoration(
                                hintText: _editingCategoryId != null
                                    ? 'Edit category name'
                                    : (isAtLimit ? 'Maximum 8 categories' : 'New category name'),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.primaryColor),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onSubmitted: (_) => _saveCategory(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                            onPressed: (_editingCategoryId != null || !isAtLimit) ? _saveCategory : null,
                            child: Text(_editingCategoryId != null ? 'Save' : 'Add', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      if (_editingCategoryId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _editingCategoryId = null;
                                _controller.clear();
                              });
                            },
                            child: const Text('Cancel Edit', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
