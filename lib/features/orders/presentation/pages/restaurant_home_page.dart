/*
 * THESIS: Browse a useful sample menu, build a real order, and let the kitchen
 * move that same receipt forward; refuse the billing-app scanner as the home.
 * OWN-WORLD: Deep herb green, citrus yellow, oat paper, ink rules, and compact
 * menu-board controls; IBM Plex Sans stays the incumbent workhorse face.
 * STORY: Guests choose dishes and quantities, add a name and kitchen note, then
 * submit a locally saved demo order; staff can review and advance its status.
 * FIRST VIEWPORT: Menu title and demo notice above a category rail and food
 * tiles; a receipt stays visible at desktop widths and becomes a bottom action
 * on phones. FORM: Task-first restaurant order board, responsive split staging.
 */
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/restaurant_order.dart';
import '../../domain/repositories/order_repository.dart';

const _ink = Color(0xFF1B2922);
const _paper = Color(0xFFF3F2EB);
const _leaf = Color(0xFF1F4D3A);
const _citrus = Color(0xFFE2A93B);
const _muted = Color(0xFF647168);

class RestaurantHomePage extends StatefulWidget {
  final OrderRepository orderRepository;
  const RestaurantHomePage({super.key, required this.orderRepository});

  @override
  State<RestaurantHomePage> createState() => _RestaurantHomePageState();
}

class _RestaurantHomePageState extends State<RestaurantHomePage> {
  final Map<String, int> _quantities = {};
  final _searchController = TextEditingController();
  String _category = 'Everything';
  String _search = '';
  bool _kitchen = false;
  bool _ordersLoading = true;
  String? _ordersError;
  List<RestaurantOrder> _savedOrders = [];

  int get _cartCount => _quantities.values.fold(0, (sum, count) => sum + count);

  double _cartTotal(List<Product> products) {
    return products.fold<double>(
      0,
      (sum, product) => sum + product.price * (_quantities[product.id] ?? 0),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _ordersLoading = true;
      _ordersError = null;
    });
    try {
      final orders = await widget.orderRepository.getOrders();
      if (!mounted) return;
      setState(() {
        _savedOrders = orders;
        _ordersLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ordersError = 'Saved orders could not be read: $error';
        _ordersLoading = false;
      });
    }
  }

  void _changeQuantity(Product product, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _quantities.remove(product.id);
      } else {
        _quantities[product.id] = quantity;
      }
    });
  }

  Future<void> _checkout(List<Product> products) async {
    final selected = products
        .where((product) => (_quantities[product.id] ?? 0) > 0)
        .toList();
    if (selected.isEmpty) return;
    final result = await showModalBottomSheet<_CheckoutDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _CheckoutSheet(
        itemCount: _cartCount,
        total: _cartTotal(selected),
      ),
    );
    if (result == null || !mounted) return;
    final order = RestaurantOrder(
      id: const Uuid().v4(),
      customerName: result.name,
      requirements: result.requirements,
      items: selected
          .map((product) => RestaurantOrderItem(
                productId: product.id,
                name: product.name,
                unitPrice: product.price,
                quantity: _quantities[product.id]!,
              ))
          .toList(),
      status: OrderStatus.received,
      createdAt: DateTime.now(),
    );
    try {
      await widget.orderRepository.submitOrder(order);
      if (!mounted) return;
      setState(() {
        _quantities.clear();
        _savedOrders = [order, ..._savedOrders];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order saved on this device for ${order.customerName}.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _leaf,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order was not saved. Please try again. ($error)'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _updateStatus(
      RestaurantOrder order, OrderStatus status) async {
    try {
      final updated = order.copyWith(status: status);
      await widget.orderRepository.updateOrder(updated);
      if (!mounted) return;
      setState(() {
        _savedOrders =
            _savedOrders.map((item) => item.id == order.id ? updated : item).toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update order status: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductBloc, ProductState>(
      listenWhen: (previous, current) =>
          current.status == ProductStatus.error &&
          current.message != previous.message,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Menu could not be loaded: ${state.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, productState) {
          final products = productState.products;
          final available = products.where((product) => product.isAvailable).toList();
          final categories = available
              .map((product) => product.category.trim())
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          categories.insert(0, 'Everything');
          final visible = available.where((product) {
            final matchesCategory =
                _category == 'Everything' || product.category == _category;
            final query = _search.trim().toLowerCase();
            return matchesCategory &&
                (query.isEmpty ||
                    product.name.toLowerCase().contains(query) ||
                    product.description.toLowerCase().contains(query));
          }).toList();

          return Scaffold(
            backgroundColor: _paper,
            appBar: _buildAppBar(),
            body: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (productState.status == ProductStatus.loading &&
                      products.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: _leaf),
                    );
                  }
                  if (productState.status == ProductStatus.error &&
                      products.isEmpty) {
                    return _MessageState(
                      icon: Icons.wifi_off_outlined,
                      title: 'The menu is unavailable',
                      detail: productState.message ??
                          'Saved menu items could not be read.',
                      actionLabel: 'Try again',
                      onAction: () =>
                          context.read<ProductBloc>().add(LoadProducts()),
                    );
                  }
                  if (_kitchen) {
                    return _buildKitchenView(constraints.maxWidth);
                  }
                  return _buildMenuView(
                    constraints.maxWidth,
                    products,
                    available,
                    visible,
                    categories,
                  );
                },
              ),
            ),
            bottomNavigationBar: !_kitchen && _cartCount > 0
                ? _mobileCheckoutBar(products)
                : null,
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return AppBar(
      backgroundColor: _paper,
      surfaceTintColor: _paper,
      toolbarHeight: 76,
      titleSpacing: 24,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _leaf,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.restaurant, color: _citrus, size: 21),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('GOOD PLATE',
                  style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      letterSpacing: 1.35,
                      fontWeight: FontWeight.w800)),
              Text('ORDER BOARD',
                  style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
      actions: [
        if (compact)
          IconButton(
            tooltip: 'Manage menu',
            onPressed: () => context.push('/products'),
            icon: const Icon(Icons.tune, color: _ink),
          )
        else
          TextButton.icon(
            onPressed: () => context.push('/products'),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Manage menu'),
            style: TextButton.styleFrom(foregroundColor: _ink),
          ),
        if (!compact) const SizedBox(width: 4),
        Padding(
          padding: EdgeInsets.only(right: compact ? 8 : 20),
          child: compact
              ? IconButton.filledTonal(
                  tooltip: _kitchen ? 'Return to menu' : 'Open kitchen orders',
                  onPressed: () {
                    setState(() => _kitchen = !_kitchen);
                    if (_kitchen) _loadOrders();
                  },
                  icon: Icon(
                      _kitchen ? Icons.menu_book_outlined : Icons.receipt_long),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        _kitchen ? _leaf : const Color(0xFFE8E8DB),
                    foregroundColor: _kitchen ? Colors.white : _ink,
                  ),
                )
              : FilledButton.tonalIcon(
                  onPressed: () {
                    setState(() => _kitchen = !_kitchen);
                    if (_kitchen) _loadOrders();
                  },
                  icon: Icon(
                      _kitchen ? Icons.menu_book_outlined : Icons.receipt_long),
                  label: Text(_kitchen ? 'Menu' : 'Kitchen'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _kitchen ? _leaf : const Color(0xFFE8E8DB),
                    foregroundColor: _kitchen ? Colors.white : _ink,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMenuView(
    double width,
    List<Product> allProducts,
    List<Product> available,
    List<Product> visible,
    List<String> categories,
  ) {
    final isWide = width >= 900;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _demoNotice(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Good things, made to order.',
                  style: TextStyle(
                      fontSize: 30,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.8)),
              const SizedBox(height: 9),
              Text(
                available.isEmpty
                    ? 'The kitchen has not added anything to the menu yet.'
                    : '${available.length} ${available.length == 1 ? 'dish' : 'dishes'} on the board · Choose a dish to see what goes into it.',
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _searchField(),
              const SizedBox(height: 15),
              _categoryRail(categories),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          Expanded(
            child: _MessageState(
              icon: available.isEmpty ? Icons.restaurant_menu : Icons.search_off,
              title: available.isEmpty ? 'Nothing on the menu yet' : 'No dishes found',
              detail: available.isEmpty
                  ? 'The menu manager can add the first dish.'
                  : 'Try another search or menu section.',
              actionLabel: available.isEmpty ? 'Open menu manager' : 'Clear search',
              onAction: available.isEmpty
                  ? () => context.push('/products')
                  : () {
                      _searchController.clear();
                      setState(() {
                        _search = '';
                        _category = 'Everything';
                      });
                    },
            ),
          )
        else
          Expanded(
            child: CustomScrollView(
              key: const PageStorageKey('restaurant-menu'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(22, 0, 22, isWide ? 24 : 22),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide
                          ? (width > 1300 ? 3 : 2)
                          : (width > 620 ? 2 : 1),
                      mainAxisExtent: 242,
                      mainAxisSpacing: 13,
                      crossAxisSpacing: 13,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _DishTile(
                        product: visible[index],
                        quantity: _quantities[visible[index].id] ?? 0,
                        onDetails: () => _showDishDetails(visible[index]),
                        onAdd: () =>
                            _changeQuantity(visible[index], (_quantities[visible[index].id] ?? 0) + 1),
                        onRemove: () =>
                            _changeQuantity(visible[index], (_quantities[visible[index].id] ?? 0) - 1),
                      ),
                      childCount: visible.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return isWide
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Padding(
                padding: const EdgeInsets.only(right: 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: content),
                    SizedBox(
                      width: 315,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 92),
                        child: _receiptPanel(allProducts, compact: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : content;
  }

  Widget _demoNotice() {
    return Container(
      width: double.infinity,
      color: _leaf,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 17, color: _citrus),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'LOCAL DEMO  ·  Sample menu, saved only on this device. No payments or live restaurant service.',
              style: TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _search = value),
        decoration: InputDecoration(
          hintText: 'Find a dish',
          prefixIcon: const Icon(Icons.search, color: _muted, size: 20),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  icon: const Icon(Icons.close, size: 19),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFFE0E1D8))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFFE0E1D8))),
        ),
      ),
    );
  }

  Widget _categoryRail(List<String> categories) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == _category;
          return ChoiceChip(
            label: Text(category),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => setState(() => _category = category),
            backgroundColor: Colors.white,
            selectedColor: _leaf,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
                color: selected ? _leaf : const Color(0xFFE0E1D8)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 9),
          );
        },
      ),
    );
  }

  Widget _receiptPanel(List<Product> products, {required bool compact}) {
    final picked = products
        .where((product) => (_quantities[product.id] ?? 0) > 0)
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFFE1E2D8)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Your order',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _ink)),
              ),
              Text('$_cartCount',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _muted)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('A little something for the table.',
              style: TextStyle(color: _muted, fontSize: 12)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1),
          ),
          if (picked.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Your receipt is waiting for its first dish.',
                  style: TextStyle(color: _muted, fontSize: 13)),
            )
          else
            Flexible(
              fit: compact ? FlexFit.loose : FlexFit.tight,
              child: ListView.separated(
                shrinkWrap: compact,
                itemCount: picked.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 13),
                itemBuilder: (context, index) {
                  final product = picked[index];
                  final quantity = _quantities[product.id] ?? 0;
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, color: _ink)),
                            const SizedBox(height: 3),
                            Text(
                              '${_money(product.price)} each',
                              style: const TextStyle(
                                  fontSize: 11, color: _muted),
                            ),
                          ],
                        ),
                      ),
                      _QuantityControl(
                        quantity: quantity,
                        onMinus: () => _changeQuantity(product, quantity - 1),
                        onPlus: () => _changeQuantity(product, quantity + 1),
                      ),
                    ],
                  );
                },
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              const Expanded(
                child: Text('Total',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _ink)),
              ),
              Text(
                _money(_cartTotal(picked)),
                style: const TextStyle(
                    color: _leaf, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: picked.isEmpty ? null : () => _checkout(products),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: _leaf,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
              child: const Text('Continue to details',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Demo order · no payment taken',
                style: TextStyle(color: _muted, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _mobileCheckoutBar(List<Product> products) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 11),
        child: FilledButton(
          onPressed: () => _checkout(products),
          style: FilledButton.styleFrom(
            backgroundColor: _leaf,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                    'Review $_cartCount ${_cartCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(_money(_cartTotal(products)),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDishDetails(Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 13, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4C8BD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _DishArtwork(product: product, height: 150),
              const SizedBox(height: 18),
              Text(product.name,
                  style: const TextStyle(
                      fontSize: 24,
                      color: _ink,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                product.description.isEmpty
                    ? 'Ask the kitchen for today’s details.'
                    : product.description,
                style: const TextStyle(color: _muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(_money(product.price),
                        style: const TextStyle(
                            color: _leaf,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _changeQuantity(
                          product, (_quantities[product.id] ?? 0) + 1);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add to order'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _leaf,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKitchenView(double width) {
    final activeOrders = _savedOrders
        .where((order) =>
            order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled)
        .toList();
    return Column(
      children: [
        _demoNotice(),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 27, 24, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kitchen orders',
                                  style: TextStyle(
                                      color: _ink,
                                      fontSize: 29,
                                      letterSpacing: -0.7,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text(
                                '$activeOrders active ${activeOrders.length == 1 ? 'order' : 'orders'} · Stored locally on this device',
                                style: const TextStyle(
                                    color: _muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/products'),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Edit menu'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: _leaf,
                              side: const BorderSide(color: _leaf)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Refresh orders',
                          onPressed: _loadOrders,
                          icon: const Icon(Icons.refresh, color: _leaf),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _ordersContent(width)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ordersContent(double width) {
    if (_ordersLoading) {
      return const Center(child: CircularProgressIndicator(color: _leaf));
    }
    if (_ordersError != null) {
      return _MessageState(
        icon: Icons.error_outline,
        title: 'Could not load saved orders',
        detail: _ordersError!,
        actionLabel: 'Try again',
        onAction: _loadOrders,
      );
    }
    if (_savedOrders.isEmpty) {
      return const _MessageState(
        icon: Icons.receipt_long_outlined,
        title: 'The kitchen is quiet',
        detail:
            'Orders placed from the sample menu will appear here with their quantities and kitchen notes.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      itemCount: _savedOrders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 11),
      itemBuilder: (context, index) =>
          _OrderReceipt(order: _savedOrders[index], wide: width > 650, onStatus: _updateStatus),
    );
  }
}

class _DishTile extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onDetails;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _DishTile({
    required this.product,
    required this.quantity,
    required this.onDetails,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${product.name}, ${product.category}, ${_money(product.price)}${quantity > 0 ? ', quantity $quantity in order' : ''}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: quantity > 0 ? _leaf : const Color(0xFFE1E2D8),
              width: quantity > 0 ? 1.4 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onDetails,
              child: Row(
                children: [
                  Expanded(child: _DishArtwork(product: product, height: 115)),
                  Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_money(product.price),
                            style: const TextStyle(
                                color: _leaf,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text(product.category.toUpperCase(),
                            style: const TextStyle(
                                color: _muted,
                                fontSize: 9,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 12, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onDetails,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(
                              product.description.isEmpty
                                  ? 'Tap to view dish'
                                  : product.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (quantity == 0)
                      IconButton.filledTonal(
                        tooltip: 'Add ${product.name} to order',
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, color: _leaf),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      _QuantityControl(
                        quantity: quantity,
                        onMinus: onRemove,
                        onPlus: onAdd,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DishArtwork extends StatelessWidget {
  final Product product;
  final double height;
  const _DishArtwork({required this.product, required this.height});

  @override
  Widget build(BuildContext context) {
    final index = (product.category.hashCode & 0x7fffffff) % 4;
    const backgrounds = [
      Color(0xFFF4E6C7),
      Color(0xFFDCE8D7),
      Color(0xFFEEDBD1),
      Color(0xFFDEE5ED),
    ];
    final icons = _iconFor(product.category);
    return Container(
      height: height,
      color: backgrounds[index],
      child: Stack(
        children: [
          Positioned(
            right: -7,
            top: -25,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _leaf.withValues(alpha: 0.10), width: 1),
              ),
            ),
          ),
          Center(
            child: Icon(icons,
                size: height > 130 ? 57 : 47,
                color: _leaf.withValues(alpha: 0.9)),
          ),
          Positioned(
            left: 12,
            top: 11,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(product.category,
                  style: const TextStyle(
                      fontSize: 9, color: _leaf, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QuantityControl({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Remove one',
            onPressed: onMinus,
            icon: const Icon(Icons.remove, size: 16),
            visualDensity: VisualDensity.compact,
            color: _leaf,
          ),
          SizedBox(
            width: 22,
            child: Text('$quantity',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            tooltip: 'Add one',
            onPressed: onPlus,
            icon: const Icon(Icons.add, size: 16),
            visualDensity: VisualDensity.compact,
            color: _leaf,
          ),
        ],
      ),
    );
  }
}

class _OrderReceipt extends StatelessWidget {
  final RestaurantOrder order;
  final bool wide;
  final Future<void> Function(RestaurantOrder, OrderStatus) onStatus;
  const _OrderReceipt({
    required this.order,
    required this.wide,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E2D8)),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(order.customerName,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _ink)),
              _StatusTag(status: order.status),
              Text(
                DateFormat('MMM d · h:mm a').format(order.createdAt.toLocal()),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              if (wide) ...[
                const SizedBox(width: 6),
                Text(_money(order.total),
                    style: const TextStyle(
                        fontSize: 17,
                        color: _leaf,
                        fontWeight: FontWeight.w800)),
                PopupMenuButton<OrderStatus>(
                  tooltip: 'Change order status',
                  initialValue: order.status,
                  onSelected: (status) => onStatus(order, status),
                  itemBuilder: (context) => OrderStatus.values
                      .map((status) => PopupMenuItem(
                            value: status,
                            child: Text(_statusLabel(status)),
                          ))
                      .toList(),
                  child: Icon(Icons.more_horiz, color: statusColor),
                ),
              ],
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 7,
            children: order.items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4EE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.quantity} × ${item.name}  ·  ${_money(item.total)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: _ink,
                            fontWeight: FontWeight.w600),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.chat_bubble_outline, color: _muted, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.requirements.isEmpty
                      ? 'Kitchen note: none'
                      : 'Kitchen note: ${order.requirements}',
                  style: const TextStyle(
                      color: _muted, height: 1.4, fontSize: 12),
                ),
              ),
              if (!wide)
                PopupMenuButton<OrderStatus>(
                  tooltip: 'Change order status',
                  onSelected: (status) => onStatus(order, status),
                  itemBuilder: (context) => OrderStatus.values
                      .map((status) => PopupMenuItem(
                            value: status,
                            child: Text(_statusLabel(status)),
                          ))
                      .toList(),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.more_horiz, color: _leaf),
                  ),
                ),
            ],
          ),
          if (!wide) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('${order.itemCount} items · ${_money(order.total)}',
                      style: const TextStyle(
                          color: _ink, fontWeight: FontWeight.w700)),
                ),
                Text(_statusLabel(order.status),
                    style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final OrderStatus status;
  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_statusLabel(status),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: _leaf),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _muted, fontSize: 13, height: 1.45)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutDetails {
  final String name;
  final String requirements;
  const _CheckoutDetails(this.name, this.requirements);
}

class _CheckoutSheet extends StatefulWidget {
  final int itemCount;
  final double total;
  const _CheckoutSheet({required this.itemCount, required this.total});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _requirements = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _requirements.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 14, 22, bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFC4C8BD),
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('A name for the ticket',
                  style: TextStyle(
                      color: _ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '${widget.itemCount} items · ${_money(widget.total)}. This demo order is saved on this device only.',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const ValueKey('checkout-customer-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Customer name',
                  hintText: 'Name on the order',
                  prefixIcon: Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name for the order.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('checkout-requirements'),
                controller: _requirements,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'Kitchen note (optional)',
                  hintText: 'Allergies or other order requirements',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.chat_bubble_outline),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(
                        context,
                        _CheckoutDetails(
                            _name.text.trim(), _requirements.text.trim()),
                      );
                    }
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Save demo order'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _leaf,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(String category) {
  final value = category.toLowerCase();
  if (value.contains('drink') || value.contains('beverage')) {
    return Icons.local_cafe_outlined;
  }
  if (value.contains('sweet') || value.contains('dessert')) {
    return Icons.cake_outlined;
  }
  if (value.contains('side')) return Icons.fastfood_outlined;
  if (value.contains('plate') || value.contains('starter')) {
    return Icons.restaurant_outlined;
  }
  return Icons.restaurant_menu;
}

Color _statusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.received:
      return const Color(0xFF9A5A0B);
    case OrderStatus.preparing:
      return const Color(0xFF315E94);
    case OrderStatus.ready:
      return _leaf;
    case OrderStatus.completed:
      return _muted;
    case OrderStatus.cancelled:
      return const Color(0xFFB33B32);
  }
}

String _statusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.received:
      return 'Received';
    case OrderStatus.preparing:
      return 'Preparing';
    case OrderStatus.ready:
      return 'Ready';
    case OrderStatus.completed:
      return 'Completed';
    case OrderStatus.cancelled:
      return 'Cancelled';
  }
}

String _money(double amount) => '₹${amount.toStringAsFixed(2)}';
