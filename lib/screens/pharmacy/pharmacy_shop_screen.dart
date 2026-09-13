import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/models/pharmacy_product.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_cart_screen.dart';
import 'package:aadya_plus/utils/constants.dart';

class PharmacyShopScreen extends StatefulWidget {
  final String? category;

  const PharmacyShopScreen({super.key, this.category});

  @override
  State<PharmacyShopScreen> createState() => _PharmacyShopScreenState();
}

class _PharmacyShopScreenState extends State<PharmacyShopScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppConstants.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.category ?? 'Shop',
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
        ),
        actions: [
          Consumer<PharmacyProvider>(
            builder: (context, provider, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PharmacyCartScreen(),
                      ),
                    ),
                  ),
                  if (provider.cartCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '${provider.cartCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                cursorColor: AppConstants.primaryColor,
                decoration: InputDecoration(
                  hintText: 'Search medicines...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: AppConstants.primaryColor, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.2), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
                  ),
                ),
              ),
            ),
            // Products grid
            Expanded(
              child: Consumer<PharmacyProvider>(
                builder: (context, provider, _) {
                  List<PharmacyProduct> products;
                  if (_searchQuery.isNotEmpty) {
                    products = provider.searchProducts(_searchQuery);
                  } else if (widget.category != null) {
                    products =
                        provider.getProductsByCategory(widget.category!);
                  } else {
                    products = provider.allProducts;
                  }

                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medication_outlined,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return _ShopProductCard(product: products[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopProductCard extends StatelessWidget {
  final PharmacyProduct product;

  const _ShopProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PharmacyProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Icon(
                  Icons.medication,
                  size: 40,
                  color: AppConstants.primaryColor.withOpacity(0.3),
                ),
              ),
              if (product.discount > 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-${product.discount.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (product.isNew)
                Positioned(
                  top: product.discount > 0 ? 32 : 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (product.prescriptionRequired)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.description, size: 11, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'Rx',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Wishlist button
              Positioned(
                bottom: 8,
                right: 8,
                child: Consumer<PharmacyProvider>(
                  builder: (context, prov, _) {
                    final inWishlist = prov.isInWishlist(product.id);
                    return GestureDetector(
                      onTap: () => prov.toggleWishlist(product.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: inWishlist
                              ? Colors.red[50]
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          inWishlist
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 18,
                          color:
                              inWishlist ? Colors.red : Colors.grey[400],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.category,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppConstants.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (product.brand.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.brand,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.packSize,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (product.rating > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                            5,
                            (i) => Icon(
                                  i < product.rating.floor()
                                      ? Icons.star
                                      : (i < product.rating
                                          ? Icons.star_half
                                          : Icons.star_border),
                                  size: 13,
                                  color: Colors.amber,
                                )),
                        const SizedBox(width: 4),
                        Text(
                          '(${product.reviews})',
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  // Price
                  Row(
                    children: [
                      Text(
                        '₹${product.discountedPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product.discount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product.discount > 0)
                    Text(
                      'Save ₹${product.savings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 6),
                  // Stock + Add to Cart
                  Row(
                    children: [
                      if (product.stock > 0)
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'In Stock',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Out of Stock',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red[700],
                          ),
                        ),
                      const Spacer(),
                      SizedBox(
                        height: 30,
                        child: ElevatedButton(
                          onPressed: product.stock > 0
                              ? () {
                                  provider.addToCart(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${product.name} added to cart'),
                                      backgroundColor: Colors.green,
                                      duration:
                                          const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
