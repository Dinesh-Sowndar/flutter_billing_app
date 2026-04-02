import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:billing_app/core/widgets/app_back_button.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/services/sync_service.dart';
import 'package:billing_app/core/service_locator.dart' as di;
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
  final _searchController = TextEditingController();
  final _uuid = const Uuid();
  final List<String> _quickTemplates = const [
    'Beverages',
    'Snacks',
    'Dairy',
    'Bakery',
    'Household',
  ];

  String? _editingCategoryId;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String input) => input.trim().toLowerCase();

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool _hasDuplicateName(String name, {String? ignoreId}) {
    final normalized = _normalize(name);
    return HiveDatabase.categoryBox.values.any((category) {
      if (ignoreId != null && category.id == ignoreId) return false;
      return _normalize(category.name) == normalized;
    });
  }

  int _usageCount(String categoryId) {
    return HiveDatabase.productBox.values
        .where((p) => p.categoryId == categoryId)
        .length;
  }

  int _linkedProductCount() {
    return HiveDatabase.productBox.values
        .where((p) => p.categoryId != null)
        .length;
  }

  Future<void> _addTemplateCategory(String name) async {
    if (_hasDuplicateName(name)) {
      _showSnack('Category "$name" already exists.');
      return;
    }

    final box = HiveDatabase.categoryBox;
    if (box.length >= 8) {
      _showSnack('Maximum 8 categories allowed.',
          color: const Color(0xFFF59E0B));
      return;
    }

    final newCategory = CategoryModel(
      id: _uuid.v4(),
      name: name,
      pendingSync: true,
    );
    await box.add(newCategory);

    final syncService = di.sl<SyncService>();
    if (syncService.isOnline) {
      await syncService.pushCategory(newCategory);
    }

    _showSnack('Added "$name" category.', color: const Color(0xFF10B981));
  }

  Future<void> _saveCategory() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter a category name.');
      return;
    }

    if (_hasDuplicateName(name, ignoreId: _editingCategoryId)) {
      _showSnack('Category name already exists. Use a different name.');
      return;
    }

    final box = HiveDatabase.categoryBox;
    String? savedId;

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
        savedId = category.id;
      }
    } else {
      // Add
      if (box.length >= 8) {
        _showSnack('Maximum 8 categories allowed.',
            color: const Color(0xFFF59E0B));
        return;
      }
      final newCategory = CategoryModel(
        id: _uuid.v4(),
        name: name,
        pendingSync: true,
      );
      await box.add(newCategory);
      savedId = newCategory.id;
    }

    // Sync the saved category to Firestore if online.
    final syncService = di.sl<SyncService>();
    if (savedId != null) {
      final saved = box.values.where((c) => c.id == savedId).firstOrNull;
      if (saved != null && syncService.isOnline) {
        await syncService.pushCategory(saved);
      }
    }

    _showSnack(
      _editingCategoryId != null
          ? 'Category updated successfully.'
          : 'Category added successfully.',
      color: const Color(0xFF10B981),
    );

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

  Future<void> _confirmAndDeleteCategory(CategoryModel category) async {
    final usedBy = _usageCount(category.id);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Category?'),
          content: Text(
            usedBy > 0
                ? '"${category.name}" is used by $usedBy product(s). Deleting it will unassign those products. Continue?'
                : 'Are you sure you want to delete "${category.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteCategory(category);
      _showSnack('Category deleted.', color: const Color(0xFF10B981));
    }
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
          final updatedPModel =
              product.toEntity().copyWith(categoryId: null, pendingSync: true);
          final updatedModel = ProductModel.fromEntity(updatedPModel);
          await productBox.putAt(i, updatedModel);
        }
      }
      await box.deleteAt(index);
      // Delete from Firestore as well.
      await di.sl<SyncService>().deleteCategory(category.id);

      if (_editingCategoryId == category.id) {
        setState(() {
          _editingCategoryId = null;
          _controller.clear();
        });
      }
    }
  }

  List<CategoryModel> _filteredCategories(List<CategoryModel> categories) {
    final q = _normalize(_query);
    if (q.isEmpty) return categories;
    return categories.where((c) => _normalize(c.name).contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mergedListenable = Listenable.merge([
      HiveDatabase.categoryBox.listenable(),
      HiveDatabase.productBox.listenable(),
    ]);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: context.canPop()
            ? AppBackButton(onPressed: () => context.pop())
            : null,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          'Manage Categories',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'View Inventory',
            onPressed: () => context.push('/products'),
            icon: const Icon(Icons.inventory_2_rounded),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: AnimatedBuilder(
        animation: mergedListenable,
        builder: (context, __) {
          final allCategories = HiveDatabase.categoryBox.values.toList();
          final categories = _filteredCategories(allCategories);
          final isAtLimit = allCategories.length >= 8;
          final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

          return SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildStatChip(
                                    icon: Icons.category_rounded,
                                    label: '${allCategories.length}/8',
                                    subtitle: 'Categories',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatChip(
                                    icon: Icons.link_rounded,
                                    label: _linkedProductCount().toString(),
                                    subtitle: 'Linked Products',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _query = value),
                                decoration: InputDecoration(
                                  hintText: 'Search categories',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _query = '');
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: AppTheme.primaryColor),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Quick Add Templates',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.sp,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _quickTemplates.map((name) {
                                  final disabled =
                                      isAtLimit || _hasDuplicateName(name);
                                  return ActionChip(
                                    onPressed: disabled
                                        ? null
                                        : () {
                                            _addTemplateCategory(name);
                                          },
                                    avatar: const Icon(Icons.add, size: 16),
                                    label: Text(name,
                                        style: TextStyle(fontSize: 12.sp)),
                                    backgroundColor: const Color(0xFFF8FAFC),
                                    side: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (categories.isEmpty)
                          _buildEmptyState(hasAny: allCategories.isNotEmpty)
                        else
                          ...categories.map((category) {
                            final usage = _usageCount(category.id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildCategoryTile(category, usage),
                            );
                          }),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FA),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: _buildComposerCard(isAtLimit),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF475569)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool hasAny}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.category_outlined,
              size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            hasAny ? 'No matching categories' : 'No categories added yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasAny
                ? 'Try a different keyword or clear search.'
                : 'Create categories to organize products faster.',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(CategoryModel category, int usage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              category.name.isNotEmpty ? category.name[0].toUpperCase() : '#',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$usage product(s)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (category.pendingSync) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Pending sync',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFEA580C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _editCategory(category);
              } else if (value == 'delete') {
                _confirmAndDeleteCategory(category);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposerCard(bool isAtLimit) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingCategoryId != null ? 'Edit Category' : 'Add Category',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: _editingCategoryId != null || !isAtLimit,
                  decoration: InputDecoration(
                    hintText: _editingCategoryId != null
                        ? 'Update category name'
                        : (isAtLimit
                            ? 'Maximum 8 categories reached'
                            : 'Enter category name'),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _saveCategory(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
                onPressed: (_editingCategoryId != null || !isAtLimit)
                    ? _saveCategory
                    : null,
                icon: Icon(
                  _editingCategoryId != null
                      ? Icons.save_rounded
                      : Icons.add_rounded,
                  size: 18,
                ),
                label: Text(
                  _editingCategoryId != null ? 'Save' : 'Add',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (_editingCategoryId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _editingCategoryId = null;
                    _controller.clear();
                  });
                },
                child: const Text(
                  'Cancel Edit',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
