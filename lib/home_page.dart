import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ae_bloom/Services/firestore_service.dart';
import 'package:ae_bloom/model/aebloom_items.dart';
import 'login_page.dart';

// --- Main HomePage Screen ---

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _pinkColor = Color(0xFFD4778B);
  static const _greenColor = Color(0xFF2E4036);

  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  int _selectedBottomNavIndex = 0;
  late Stream<List<ProductDatum>> _productsStream;
  late Stream<List<FlowerOrder>> _ordersStream;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _productsStream = _firestoreService.getProductsStream();
    _ordersStream = _firestoreService.getOrdersStream();
    _seedFirestoreIfEmpty();
  }

  Future<void> _seedFirestoreIfEmpty() async {
    try {
      await _firestoreService.seedInitialData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firestore sync note: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _refreshStreams() {
    setState(() {
      _productsStream = _firestoreService.getProductsStream();
      _ordersStream = _firestoreService.getOrdersStream();
    });
    _seedFirestoreIfEmpty();
  }

  List<ProductDatum> _applySearchFilter(List<ProductDatum> products) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((product) {
      final nameMatch = product.productName.toLowerCase().contains(query);
      final typeMatch = product.flowerType.toLowerCase().contains(query);
      return nameMatch || typeMatch;
    }).toList();
  }

  Future<void> _addProductItem() async {
    final newProduct = await showDialog<ProductDatum>(
      context: context,
      builder: (context) => const _ProductFormDialog(),
    );

    if (newProduct == null || !mounted) return;

    try {
      await _firestoreService.addProduct(
        productName: newProduct.productName,
        flowerType: newProduct.flowerType,
        productImage: newProduct.productImage,
        price: newProduct.price,
        inStock: newProduct.inStock,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${newProduct.productName} to Firestore')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add product: $e')),
      );
    }
  }

  Future<void> _editProductItem(ProductDatum product) async {
    final updatedProduct = await showDialog<ProductDatum>(
      context: context,
      builder: (context) => _ProductFormDialog(product: product),
    );

    if (updatedProduct == null || !mounted) return;

    try {
      await _firestoreService.saveProduct(updatedProduct);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${updatedProduct.productName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update product: $e')),
      );
    }
  }

  Future<void> _deleteProductItem(ProductDatum product) async {
    try {
      await _firestoreService.deleteProduct(product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${product.productName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete product: $e')),
      );
    }
  }

  Future<void> _openNewOrderForm([ProductDatum? initialProduct]) async {
    List<ProductDatum> products;
    try {
      products = await _firestoreService.getProductsOnce();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load products from Firestore: $e')),
      );
      return;
    }

    if (!mounted) return;

    final inStockProducts = products.where((product) => product.inStock).toList();
    if (inStockProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No in-stock products available to order.')),
      );
      return;
    }

    final ProductDatum selectedProduct =
        initialProduct != null && initialProduct.inStock
            ? initialProduct
            : inStockProducts.first;

    final newOrder = await showDialog<FlowerOrder>(
      context: context,
      builder: (context) => _NewOrderDialog(
        products: inStockProducts,
        initialProduct: selectedProduct,
      ),
    );

    if (newOrder == null || !mounted) return;

    try {
      await _firestoreService.createOrder(
        productName: newOrder.productName,
        customerName: newOrder.customerName,
        quantity: newOrder.quantity,
        total: newOrder.total,
      );
      if (!mounted) return;
      setState(() => _selectedBottomNavIndex = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order for ${newOrder.productName} saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save order: $e')),
      );
    }
  }

  Future<void> _updateOrderStatus(FlowerOrder order, OrderStatus status) async {
    if (order.docId == null) return;
    try {
      await _firestoreService.updateOrderStatus(order.docId!, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${order.productName} marked as ${status.label}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order: $e')),
      );
    }
  }

  Future<void> _deleteOrder(FlowerOrder order) async {
    if (order.docId == null) return;
    try {
      await _firestoreService.deleteOrder(order.docId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted order for ${order.customerName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete order: $e')),
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AEBLOOM DASHBOARD',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        backgroundColor: _pinkColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Connected to Cloud Firestore')),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: _pinkColor),
              accountName: const Text('AEBloom Manager'),
              accountEmail: Text(
                FirebaseAuth.instance.currentUser?.email ?? 'admin@aebloom.com',
              ),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.local_florist, color: _pinkColor),
              ),
            ),
            _drawerItem(Icons.dashboard_outlined, 'Dashboard', 0),
            _drawerItem(Icons.local_florist_outlined, 'Products & Flowers', 1),
            _drawerItem(Icons.receipt_long_outlined, 'Order Management', 2),
            _drawerItem(Icons.analytics_outlined, 'Sales & Analytics', 3),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout'),
              onTap: _signOut,
            ),
          ],
        ),
      ),
      body: switch (_selectedBottomNavIndex) {
        0 => _buildDashboardView(),
        1 => _buildProductsView(),
        2 => _buildOrdersView(),
        _ => _buildAnalyticsView(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedBottomNavIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedBottomNavIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.local_florist_outlined), label: 'Products'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.analytics_outlined), label: 'Sales'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewOrderForm,
        backgroundColor: _pinkColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int destination) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: _selectedBottomNavIndex == destination,
      onTap: () {
        Navigator.pop(context);
        setState(() => _selectedBottomNavIndex = destination);
      },
    );
  }

  Widget _buildDashboardView() {
    return StreamBuilder<List<FlowerOrder>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            'Unable to load orders from Firestore.\n${snapshot.error}',
          );
        }

        final orders = snapshot.data ?? const <FlowerOrder>[];
        final pendingOrders = orders
            .where((order) => order.status != OrderStatus.delivered)
            .length;
        final sales = orders.fold<double>(0, (total, order) => total + order.total);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Store Metrics',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _greenColor),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    Icons.monetization_on,
                    'Sales Total',
                    _peso(sales),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    Icons.shopping_basket,
                    'Active Orders',
                    '$pendingOrders Pending',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Flower Orders',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _greenColor),
            ),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('No orders in Firestore yet.'),
                  ),
                ),
              )
            else
              ...orders.take(3).map(_orderCard),
          ],
        );
      },
    );
  }

  Widget _metricCard(IconData icon, String label, String value) {
    return Card(
      color: _pinkColor.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: _pinkColor, size: 30),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.black54)),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    labelText: 'Search Flowers',
                    hintText: 'e.g. Rose, Sunflower, Tulip...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addProductItem,
                style: FilledButton.styleFrom(
                  backgroundColor: _pinkColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ProductDatum>>(
            stream: _productsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildErrorState(
                  'Unable to load products from Firestore.\n${snapshot.error}',
                );
              }

              final allProducts = snapshot.data ?? const <ProductDatum>[];
              if (allProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No products in Firestore yet.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _seedFirestoreIfEmpty,
                        style:
                            FilledButton.styleFrom(backgroundColor: _pinkColor),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Seed Sample Products'),
                      ),
                    ],
                  ),
                );
              }

              final filteredProducts = _applySearchFilter(allProducts);
              if (filteredProducts.isEmpty) {
                return const Center(
                  child: Text('No flower products matched your search.'),
                );
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredProducts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: product.productImage.isNotEmpty
                                ? Image.network(
                                    product.productImage,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Icon(
                                        Icons.local_florist,
                                        color: _pinkColor,
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: Icon(
                                      Icons.local_florist,
                                      color: _pinkColor,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  product.flowerType,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                Text(
                                  _peso(product.price),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              product.inStock
                                  ? FilledButton(
                                      onPressed: () =>
                                          _openNewOrderForm(product),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _pinkColor,
                                      ),
                                      child: const Text('Order'),
                                    )
                                  : const Chip(label: Text('Out of stock')),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: Colors.blueAccent,
                                    ),
                                    onPressed: () => _editProductItem(product),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () =>
                                        _deleteProductItem(product),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersView() {
    return StreamBuilder<List<FlowerOrder>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            'Unable to load orders from Firestore.\n${snapshot.error}',
          );
        }

        final orders = snapshot.data ?? const <FlowerOrder>[];
        if (orders.isEmpty) {
          return const Center(
            child: Text('No orders yet. Create your first flower order.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) => _orderCard(orders[index]),
        );
      },
    );
  }

  Widget _orderCard(FlowerOrder order) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _pinkColor.withValues(alpha: 0.18),
          child: const Icon(Icons.local_florist, color: _pinkColor),
        ),
        title: Text('${order.productName} (${order.quantity} pcs)'),
        subtitle:
            Text('Customer: ${order.customerName}\n${_peso(order.total)}'),
        trailing: PopupMenuButton<String>(
          tooltip: 'Update order status',
          onSelected: (action) {
            if (action == 'delete') {
              _deleteOrder(order);
            } else {
              _updateOrderStatus(order, OrderStatus.fromLabel(action));
            }
          },
          itemBuilder: (context) => [
            ...OrderStatus.values.map(
              (status) => PopupMenuItem<String>(
                value: status.label,
                child: Text('Mark as ${status.label}'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text(
                'Delete Order',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
          child: Chip(
            label: Text(order.status.label),
            backgroundColor: order.status.color,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsView() {
    return StreamBuilder<List<ProductDatum>>(
      stream: _productsStream,
      builder: (context, productSnapshot) {
        return StreamBuilder<List<FlowerOrder>>(
          stream: _ordersStream,
          builder: (context, orderSnapshot) {
            if ((productSnapshot.connectionState == ConnectionState.waiting &&
                    !productSnapshot.hasData) ||
                (orderSnapshot.connectionState == ConnectionState.waiting &&
                    !orderSnapshot.hasData)) {
              return const Center(child: CircularProgressIndicator());
            }

            final products = productSnapshot.data ?? const <ProductDatum>[];
            final orders = orderSnapshot.data ?? const <FlowerOrder>[];
            final totalRevenue =
                orders.fold<double>(0, (sum, o) => sum + o.total);
            final deliveredCount = orders
                .where((o) => o.status == OrderStatus.delivered)
                .length;
            final inStockCount = products.where((p) => p.inStock).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Sales & Inventory Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _greenColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        Icons.payments_outlined,
                        'Total Revenue',
                        _peso(totalRevenue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricCard(
                        Icons.check_circle_outline,
                        'Delivered Orders',
                        '$deliveredCount / ${orders.length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        Icons.local_florist_outlined,
                        'Products Catalog',
                        '${products.length} Items',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricCard(
                        Icons.inventory_2_outlined,
                        'In Stock',
                        '$inStockCount Available',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_done, color: _pinkColor),
                    title: const Text('Cloud Firestore Connected'),
                    subtitle: Text(
                      'Collections: ${FirestoreService.productsCollection}, '
                      '${FirestoreService.ordersCollection}',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _refreshStreams,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _peso(double amount) => '₱${amount.toStringAsFixed(2)}';
}

// --- Dialog Forms ---

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});
  final ProductDatum? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageController;
  late bool _inStock;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.product?.productName ?? '');
    _typeController =
        TextEditingController(text: widget.product?.flowerType ?? '');
    _priceController = TextEditingController(
      text: widget.product != null ? widget.product!.price.toString() : '',
    );
    _imageController =
        TextEditingController(text: widget.product?.productImage ?? '');
    _inStock = widget.product?.inStock ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: 'Flower Type'),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Enter type' : null,
              ),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
                validator: (val) =>
                    double.tryParse(val ?? '') == null ? 'Enter valid price' : null,
              ),
              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                ),
              ),
              SwitchListTile(
                title: const Text('In Stock'),
                value: _inStock,
                onChanged: (val) => setState(() => _inStock = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final result = ProductDatum(
              docId: widget.product?.docId,
              id: widget.product?.id ?? DateTime.now().millisecondsSinceEpoch,
              productName: _nameController.text.trim(),
              flowerType: _typeController.text.trim(),
              productImage: _imageController.text.trim(),
              price: double.parse(_priceController.text),
              inStock: _inStock,
            );
            Navigator.pop(context, result);
          },
          child: Text(_isEditing ? 'Save Changes' : 'Add Product'),
        ),
      ],
    );
  }
}

class _NewOrderDialog extends StatefulWidget {
  const _NewOrderDialog({
    required this.products,
    required this.initialProduct,
  });
  final List<ProductDatum> products;
  final ProductDatum initialProduct;

  @override
  State<_NewOrderDialog> createState() => _NewOrderDialogState();
}

class _NewOrderDialogState extends State<_NewOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  late ProductDatum _selectedProduct;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  @override
  void dispose() {
    _customerController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  String _peso(double amount) => '₱${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final quantityInput = int.tryParse(_quantityController.text) ?? 0;
    final totalAmount = _selectedProduct.price * quantityInput;

    return AlertDialog(
      title: const Text('Create New Order'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ProductDatum>(
                initialValue: _selectedProduct,
                decoration: const InputDecoration(labelText: 'Flower product'),
                items: widget.products
                    .map(
                      (product) => DropdownMenuItem(
                        value: product,
                        child: Text(product.productName),
                      ),
                    )
                    .toList(),
                onChanged: (product) =>
                    setState(() => _selectedProduct = product!),
              ),
              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(labelText: 'Customer name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the customer name.'
                    : null,
              ),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                onChanged: (_) => setState(() {}),
                validator: (value) =>
                    int.tryParse(value ?? '') == null || int.parse(value!) < 1
                        ? 'Enter a quantity of at least 1.'
                        : null,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Order total: ${_peso(totalAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final quantity = int.parse(_quantityController.text);
            Navigator.pop(
              context,
              FlowerOrder(
                productName: _selectedProduct.productName,
                customerName: _customerController.text.trim(),
                quantity: quantity,
                total: _selectedProduct.price * quantity,
                status: OrderStatus.preparing,
                createdAt: DateTime.now(),
              ),
            );
          },
          child: const Text('Create order'),
        ),
      ],
    );
  }
}
