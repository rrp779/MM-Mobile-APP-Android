import 'dart:convert' show jsonDecode;
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../widgets/inner_page_app_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/app_icon.dart';

class BuyAgainPage extends StatefulWidget {
  const BuyAgainPage({super.key});

  @override
  State<BuyAgainPage> createState() => _BuyAgainPageState();
}

class _BuyAgainPageState extends State<BuyAgainPage> {

  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  /// STEP 1: GET PRODUCT IDS FROM ORDERS
  Future<void> _loadProducts() async {

    final client = GraphQLProvider.of(context).value;

    final prefs = await SharedPreferences.getInstance();
    String? customerEncoded = prefs.getString('customer');

    if (customerEncoded == null) {
      setState(() => _loading = false);
      return;
    }

    Map customer = jsonDecode(customerEncoded);
    String accessToken = customer['accessToken'];

    final result = await client.query(
      QueryOptions(
        document: gql(r'''
        query customer($accessToken: String!) {
          customer(customerAccessToken: $accessToken) {
            orders(first: 30) {
              edges {
                node {
                  lineItems(first: 10) {
                    edges {
                      node {
                        variant {
                          product {
                            id
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        '''),
        variables: {'accessToken': accessToken},
      ),
    );

    if (result.hasException) {
      setState(() => _loading = false);
      return;
    }

    Set<String> productIds = {};

    final orders = result.data?['customer']?['orders']?['edges'] ?? [];

    for (var order in orders) {

      final items = order['node']?['lineItems']?['edges'] ?? [];

      for (var item in items) {

        final variant = item['node']?['variant'];

        if (variant == null) continue;

        final product = variant['product'];

        if (product == null) continue;

        final id = product['id'];

        if (id != null) {
          productIds.add(id);
        }
      }
    }

    print("PRODUCT IDS: $productIds");

    await _fetchProducts(productIds.toList());
  }

  /// STEP 2: FETCH FULL PRODUCTS
  Future<void> _fetchProducts(List<String> ids) async {

    final client = GraphQLProvider.of(context).value;

    final result = await client.query(
      QueryOptions(
        document: gql(r'''
      query products($ids: [ID!]!) {
        nodes(ids: $ids) {
          ... on Product {
            id
            title
            descriptionHtml
            vendor

            featuredImage {
              url
            }

            images(first: 10) {
              edges {
                node {
                  url
                }
              }
            }

            variants(first: 20) {
              edges {
                node {
                  id
                  price { amount }
                  compareAtPrice { amount }
                  selectedOptions {
                    name
                    value
                  }
                }
              }
            }
          }
        }
      }
      '''),
        variables: {"ids": ids},
      ),
    );

    if (result.hasException) {
      setState(() => _loading = false);
      return;
    }

    /// Force correct typing
    final List nodes = result.data?["nodes"] ?? [];

    final List<Product> products = nodes
        .where((p) => p != null)
        .map<Product>((p) => Product.fromJson(
      Map<String, dynamic>.from(p),
    ))
        .toList();

    setState(() {
      _products = products;
      _loading = false;
    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.white,

      appBar: InnerPageAppBar(
        title: "Buy Again",
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())

          : _products.isEmpty
          ? const Center(child: Text("No previously purchased products"))

          : GridView.builder(

        padding: const EdgeInsets.all(8),

        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.58,
        ),

        itemCount: _products.length,

        itemBuilder: (context, index) {

          return ProductCard(
            product: _products[index],
          );

        },

      ),
    );
  }
}