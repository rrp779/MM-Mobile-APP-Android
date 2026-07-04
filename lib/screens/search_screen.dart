import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../models/product.dart';
import '../widgets/product_card.dart';
import '../graphql/search_products_query.dart';
import '../widgets/inner_page_app_bar.dart';
import '../widgets/app_icon.dart';
class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({
    super.key,
    this.initialQuery = "",
  });

  @override
  State<SearchScreen> createState() =>
      _SearchScreenState();
}

class _SearchScreenState
    extends State<SearchScreen> {
  late TextEditingController _controller;
  Timer? _debounce;

  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialQuery);

    searchQuery = widget.initialQuery;

    _controller.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce =
        Timer(const Duration(milliseconds: 500), () {
          setState(() {
            searchQuery = _controller.text.trim();
          });
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerPageAppBar(
        title: "Search",
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [

          /// SEARCH INPUT
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                onChanged: (value) {
                  setState(() {}); // for clear button toggle
                },
                decoration: InputDecoration(
                  hintText: "Search products...",
                  hintStyle: const TextStyle(fontSize: 14),

                  /// 🔍 Prefix Icon (your custom one)
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppIcon(
                      isActive: false,
                      outlinePath: 'assets/icons/SearchOutline.svg',
                      filledPath: 'assets/icons/SearchBold.svg',
                      size: 18,
                    ),
                  ),

                  /// ❌ Clear button (same behavior)
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                    },
                  )
                      : null,

                  /// 🎨 Same styling as first search
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),

                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 10,
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          /// RESULTS
          Expanded(
            child: searchQuery.isEmpty
                ? const Center(
              child: Text(
                "Start typing to search...",
                style:
                TextStyle(color: Colors.grey, fontSize: 14,),

              ),
            )
                : Query(
              options: QueryOptions(
                document:
                gql(searchProductsQuery),
                variables: {
                  "query": searchQuery,
                },
              ),
              builder:
                  (result, {refetch, fetchMore}) {
                if (result.isLoading) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                if (result.hasException) {
                  return Center(
                    child: Text(
                      result.exception
                          .toString(),
                    ),
                  );
                }

                final items =
                result.data!['products']
                ['edges']
                as List;

                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      "No products found",
                    ),
                  );
                }

                final products = items
                    .map((e) => Product.fromJson(
                    e['node']))
                    .toList();

                return GridView.builder(
                  padding:
                  const EdgeInsets.all(16),
                  itemCount:
                  products.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing:
                    16,
                    crossAxisSpacing:
                    16,
                    childAspectRatio:
                    0.50,
                  ),
                  itemBuilder:
                      (_, index) {
                    return ProductCard(
                      product:
                      products[index],
                    );
                  },

                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

