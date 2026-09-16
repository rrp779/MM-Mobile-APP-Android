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

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _controller;
  Timer? _debounce;

  String searchQuery = "";

  static const List<String> _popularSuggestions = [
    "Lipstick",
    "Foundation",
    "Kajal",
    "Primer",
    "Eye Liner",
    "MAC",
    "Shopaarel",
    "Brush",
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    searchQuery = widget.initialQuery.trim();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final text = value.trim();
      if (text != searchQuery) {
        setState(() {
          searchQuery = text;
        });
      }
    });
  }

  void _submitSearch(String value) {
    _debounce?.cancel();
    final text = value.trim();
    if (text != searchQuery) {
      setState(() {
        searchQuery = text;
      });
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      searchQuery = "";
    });
  }

  void _applySuggestion(String tag) {
    _debounce?.cancel();
    _controller.text = tag;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: tag.length),
    );
    setState(() {
      searchQuery = tag;
    });
  }

  /// Converts user input into a targeted Shopify Storefront search query.
  /// Searches title, tag, vendor, and product_type while avoiding broad description matching.
  String _buildShopifyQuery(String input) {
    if (input.trim().isEmpty) return "";

    // Normalize abbreviations like M.A.C -> MAC, L.A. -> LA
    String cleaned = input.replaceAllMapped(
      RegExp(r'([A-Za-z])\.([A-Za-z])\.?'),
      (match) => '${match.group(1)}${match.group(2)}',
    );

    // Remove characters that could break GraphQL search syntax
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
    if (cleaned.isEmpty) return "";

    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return "";

    return words
        .map((w) => '(title:$w* OR tag:$w* OR vendor:$w* OR product_type:$w*)')
        .join(' AND ');
  }

  /// Client-side verification to ensure products returned genuinely match the search keywords.
  bool _isProductRelevant(Product product, String rawQuery) {
    final trimmed = rawQuery.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    final words = trimmed
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return false;

    final title = product.title.toLowerCase();
    final vendor = (product.vendor ?? product.brandTitle ?? '').toLowerCase();
    final tags = product.tags.map((t) => t.toLowerCase()).toList();

    // Check if at least one word from the search query matches title, vendor, or tags
    return words.any((w) =>
        title.contains(w) ||
        vendor.contains(w) ||
        tags.any((t) => t.contains(w)));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedShopifyQuery = _buildShopifyQuery(searchQuery);

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
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {}); // Toggle clear button
                  _onSearchChanged(value);
                },
                onSubmitted: _submitSearch,
                decoration: InputDecoration(
                  hintText: "Search products, brands...",
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(11),
                    child: AppIcon(
                      isActive: false,
                      outlinePath: 'assets/icons/SearchOutline.svg',
                      filledPath: 'assets/icons/SearchBold.svg',
                      size: 18,
                    ),
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                          onPressed: _clearSearch,
                        )
                      : null,
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

          /// RESULTS AREA
          Expanded(
            child: searchQuery.isEmpty
                ? _buildInitialPrompt()
                : formattedShopifyQuery.isEmpty
                    ? _buildNoResultsState(searchQuery)
                    : Query(
                        options: QueryOptions(
                          document: gql(searchProductsQuery),
                          variables: {
                            "query": formattedShopifyQuery,
                          },
                          fetchPolicy: FetchPolicy.networkOnly,
                        ),
                        builder: (result, {refetch, fetchMore}) {
                          if (result.isLoading) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF7C3AED),
                              ),
                            );
                          }

                          if (result.hasException) {
                            return _buildNoResultsState(searchQuery);
                          }

                          final items = (result.data?['products']?['edges']
                              as List?) ?? [];

                          if (items.isEmpty) {
                            return _buildNoResultsState(searchQuery);
                          }

                          // Parse and filter products for relevance
                          final products = items
                              .map((e) => Product.fromJson(e['node']))
                              .where((p) => _isProductRelevant(p, searchQuery))
                              .toList();

                          if (products.isEmpty) {
                            return _buildNoResultsState(searchQuery);
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.50,
                            ),
                            itemBuilder: (_, index) {
                              return ProductCard(
                                product: products[index],
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

  /// Initial screen shown when user hasn't entered a query yet
  Widget _buildInitialPrompt() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Popular Searches",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E2D),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _popularSuggestions.map((tag) {
              return ActionChip(
                label: Text(tag),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
                backgroundColor: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                onPressed: () => _applySuggestion(tag),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Dedicated empty state when no products match the query
  Widget _buildNoResultsState(String query) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 46,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Products Found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E2D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              query.isNotEmpty
                  ? 'We couldn\'t find any products matching "$query".\nPlease check your spelling or try different keywords.'
                  : 'No products match your search. Please try another keyword.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Popular suggestion chips
            const Text(
              "Try searching for:",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _popularSuggestions.take(6).map((tag) {
                return ActionChip(
                  label: Text(tag),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7C3AED),
                  ),
                  backgroundColor: const Color(0xFFF5F3FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFFDDD6FE)),
                  ),
                  onPressed: () => _applySuggestion(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text("Clear Search"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

