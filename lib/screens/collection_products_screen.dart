import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/product_card_skeleton.dart';
import '../widgets/inner_page_app_bar.dart';
import '../screens/product_filter_screen.dart';
import '../models/collection.dart';
class CollectionProductsScreen extends StatefulWidget {
  final String collectionId;
  final String collectionTitle;
  final bool isBrand;
  final String? collectionHandle;

  const CollectionProductsScreen({
    super.key,
    required this.collectionId,
    required this.collectionTitle,
    this.collectionHandle,
    this.isBrand = true,
  });

  @override
  State<CollectionProductsScreen> createState() =>
      _CollectionProductsScreenState();

}

enum SortType {
  popularity,
  priceLowHigh,
  priceHighLow,
  newArrivals,
  discountHighLow,
  discountLowHigh,
}

class _CollectionProductsScreenState extends State<CollectionProductsScreen> {
  List<CollectionModel> _brands = [];
  final ScrollController _scrollController = ScrollController();
  Function? _refetch;
  SortType _selectedSort = SortType.popularity;
  Set<String> _selectedBrands = {};
  Set<String> _selectedPrices = {};
  String _sortKey = "BEST_SELLING";
  bool _reverse = false;

  RangeValues _priceRange = const RangeValues(0, 5000);

  String? _endCursor;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;

  VoidCallback? _loadMore;

  bool get isGid => widget.collectionId.startsWith("gid://");

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasNextPage) {
        _loadMore?.call();
      }
    });
  }

  double _discount(Product product) {
    final price = product.price;
    final compare = product.compareAt;

    if (compare == null || compare == 0) return 0;

    return ((compare - price) / compare) * 100;
  }
  String _normalizeHandle(String handle) {
    return handle
        .toLowerCase()
        .replaceAll(" ", "-")
        .replaceAll("--", "-")
        .trim();
  }
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: InnerPageAppBar(
        title: widget.collectionTitle,
      ),

      body: Query(
        options: QueryOptions(
          document: gql(
            widget.collectionId.startsWith("gid://")
                ? collectionByIdQuery
                : collectionByHandleQuery,
          ),
          variables: {
            if (widget.collectionId.startsWith("gid://"))
              "id": widget.collectionId
            else
              "handle": _normalizeHandle(
                widget.collectionHandle ?? widget.collectionId,
              ),
            "first": 100,
            "after": null,
            "sortKey": _sortKey,
            "reverse": _reverse,
          },
        ),

        builder: (result, {fetchMore, refetch}) {

          _refetch = refetch;

          if (result.isLoading && result.data == null) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.50,
              ),
              itemBuilder: (_, __) => const ProductCardSkeleton(),
            );
          }

          if (result.hasException) {
            return Center(
              child: Text(result.exception.toString()),
            );
          }

          Map<String, dynamic>? collection;

          //print("FULL DATA: ${result.data}");

          if (isGid) {
            collection = result.data?['node'];
          } else {
            collection = result.data?['collectionByHandle'];
          }
          debugPrint("ID: ${widget.collectionId}");
          if (collection == null) {
            return Center(
              child: Text(
                "Collection not found\n\nCheck handle/id",
                textAlign: TextAlign.center,
              ),
            );
          }

          final productsData = collection['products'];

          if (productsData == null) {
            return const Center(child: Text("No products found"));
          }

          final List edges = (productsData['edges'] ?? []) as List;

          /// 🔥 EXTRACT BRAND + COUNT
          final Map<String, int> brandCountMap = {};
          for (var e in edges) {
            final p = Product.fromJson(e['node']);
            final brand = p.brandTitle;
            if (brand != null && brand.isNotEmpty) {
              brandCountMap[brand] = (brandCountMap[brand] ?? 0) + 1;
            }
          }

          /// 🔥 CONVERT TO MODEL LIST
          final List<CollectionModel> brands = brandCountMap.entries
              .map((e) => CollectionModel(
            title: e.key,
            handle: e.key.toLowerCase().replaceAll(" ", "-"),
            image: '',
            mobileDescription: e.value.toString(), // 👈 store count here
          ))
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));

          _brands = brands;

          print("BRANDS WITH COUNT: ${_brands.length}");


          final List<Map<String, dynamic>> priceRanges = [
            {"label": "Rs. 0 - Rs. 499", "min": 0.0, "max": 499.0},
            {"label": "Rs. 500 - Rs. 999", "min": 500.0, "max": 999.0},
            {"label": "Rs. 1000 - Rs. 1999", "min": 1000.0, "max": 1999.0},
            {"label": "Rs. 2000 and above", "min": 2000.0, "max": double.infinity},
          ];



          /// 🔥 PRODUCTS
          List<Product> allProducts =
          edges.map((e) => Product.fromJson(e['node'])).toList();
          List<Product> products = List.from(allProducts);
          if (_selectedBrands.isNotEmpty) {
            products = allProducts.where((p) {
              final brand = (p.brandTitle ?? "").toLowerCase();
              return _selectedBrands
                  .map((b) => b.toLowerCase())
                  .contains(brand);
            }).toList();
          }
          /// 🔥 APPLY PRICE FILTER
          if (_selectedPrices.isNotEmpty) {
            products = products.where((p) {
              final price = p.price;
              for (var selected in _selectedPrices) {
                final range = priceRanges.firstWhere(
                      (r) => r["label"] == selected,
                );
                if (price >= range["min"] && price <= range["max"]) {
                  return true;
                }
              }
              return false;
            }).toList();
          }

          /// Local discount sorting
          if (_selectedSort == SortType.discountHighLow) {
            products.sort((a, b) => _discount(b).compareTo(_discount(a)));
          }

          if (_selectedSort == SortType.discountLowHigh) {
            products.sort((a, b) => _discount(a).compareTo(_discount(b)));
          }

          _hasNextPage = productsData['pageInfo']['hasNextPage'];
          _endCursor = productsData['pageInfo']['endCursor'];

          /// Pagination
          _loadMore = () async {

            if (!_hasNextPage || fetchMore == null) return;

            _isLoadingMore = true;

            await fetchMore(
              FetchMoreOptions(
                variables: {"after": _endCursor},
                updateQuery: (previous, fetchMoreResult) {

                  if (previous == null || fetchMoreResult == null) {
                    return previous!;
                  }

                  final prevCollection =
                      previous['collectionByHandle'] ?? previous['node'];

                  final newCollection =
                      fetchMoreResult['collectionByHandle'] ?? fetchMoreResult['node'];

                  final List prevEdges =
                      prevCollection['products']['edges'] ?? [];

                  final List newEdges =
                      newCollection['products']['edges'] ?? [];

                  prevEdges.addAll(newEdges);

                  prevCollection['products']['edges'] = prevEdges;

                  prevCollection['products']['pageInfo'] =
                  newCollection['products']['pageInfo'];

                  return previous;
                },
              ),
            );

            _isLoadingMore = false;
          };

          if (products.isEmpty) {
            return const Center(child: Text("No products found"));
          }



          return Column(
            children: [

              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "${products.length} Products",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),

              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const crossAxisCount = 2;
                    const spacing = 16.0;
                    const horizontalPadding = 16.0;

                    final textScale = MediaQuery.textScaleFactorOf(context);
                    final gridWidth = constraints.maxWidth - (horizontalPadding * 2);
                    final itemWidth = (gridWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

                    // ProductCard needs a bit of extra height on smaller devices / larger text scales
                    // to avoid the "Quick View" button being clipped.
                    final extra = (textScale - 1).clamp(0.0, 0.6) * 28.0;
                    final mainAxisExtent = itemWidth + 175.0 + extra;

                    return GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        16,
                      ),
                      itemCount: products.length + (_isLoadingMore ? 2 : 0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        mainAxisExtent: mainAxisExtent,
                      ),
                      itemBuilder: (_, index) {
                        if (index >= products.length) {
                          return const ProductCardSkeleton();
                        }

                        final product = products[index];

                        return ProductCard(
                          key: ValueKey(product.id),
                          product: product,
                          collectionTitle: widget.collectionTitle,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      bottomNavigationBar: SafeArea(
        child: _filterSortBar(),
      ),
    );
  }

  /// Filter + Sort Bar
  Widget _filterSortBar() {
    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [

          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              onTap: () => _openFilterSheet(List.from(_brands)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune, size: 20),
                  SizedBox(width: 6),
                  Text(
                    "Filter",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            width: 1,
            height: 26,
            color: const Color(0xFFEAEAEA),
          ),

          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(14),
              ),
              onTap: () {
                if (_refetch != null) {
                  _openSortSheet(_refetch!);
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_vert, size: 20),
                  SizedBox(width: 6),
                  Text(
                    "Sort",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// SORT SHEET
  void _openSortSheet(Function refetch) {

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 👈 IMPORTANT
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
          return SafeArea(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

            const SizedBox(height: 10),

            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 16),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Sort By",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            _sortTile("Popularity", SortType.popularity, refetch),
            _sortTile("Price: Low to High", SortType.priceLowHigh, refetch),
            _sortTile("Price: High to Low", SortType.priceHighLow, refetch),
            _sortTile("Discount: High to Low", SortType.discountHighLow, refetch),
            _sortTile("Discount: Low to High", SortType.discountLowHigh, refetch),
            _sortTile("New Arrivals", SortType.newArrivals, refetch),

            const SizedBox(height: 20),
          ],
              )
        );
      },
    );
  }

  Widget _sortTile(String title, SortType type, Function refetch) {

    bool selected = _selectedSort == type;

    return InkWell(
      onTap: () {

        setState(() {

          _selectedSort = type;

          switch (type) {

            case SortType.popularity:
              _sortKey = "BEST_SELLING";
              _reverse = false;
              break;

            case SortType.priceLowHigh:
              _sortKey = "PRICE";
              _reverse = false;
              break;

            case SortType.priceHighLow:
              _sortKey = "PRICE";
              _reverse = true;
              break;

            case SortType.newArrivals:
              _sortKey = "CREATED";
              _reverse = true;
              break;

            case SortType.discountHighLow:
            case SortType.discountLowHigh:
              break;
          }
        });

        refetch();

        Navigator.pop(context);
      },

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [

            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16)),
            ),

            selected
                ? const CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFFEA0180),
              child: Icon(Icons.check, size: 16, color: Colors.white),
            )
                : Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, width: 2),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilterSheet(List<CollectionModel> brands) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilterScreen(
          selectedBrands: _selectedBrands,
          selectedPrices:_selectedPrices,
          brands: brands,
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _selectedBrands = result["brands"] ?? {};
        _selectedPrices = result["prices"] ?? {};
      });
    }
  }
}
const String collectionByHandleQuery = r'''
query GetCollectionProducts(
  $handle: String!,
  $first: Int!,
  $after: String,
  $sortKey: ProductCollectionSortKeys,
  $reverse: Boolean
) {
  collectionByHandle(handle: $handle) {
    id
    title
    
    products(
      first: $first
      after: $after
      sortKey: $sortKey
      reverse: $reverse
    ) {
      pageInfo {
        hasNextPage
        endCursor
      }
      edges {
        node {
          id
          title
          
          images(first: 1) {
            edges { node { url } }
          }
          
          variants(first: 200) {
            edges {
              node {
                id
                title    
                 availableForSale  
                quantityAvailable  
               
                price { amount }
                compareAtPrice { amount }
                selectedOptions {
        name
        value
      }
              }
            }
          }
          
           collections(first: 200) {
            edges {
              node {
                title
                metafield(namespace: "custom", key: "mobile_app_setting_from_website") {
                  reference {
                    ... on Metaobject {
                      fields {
                        key
                        value
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
  }
}
''';

const String collectionByIdQuery = r'''
query GetCollectionProducts(
  $id: ID!,
  $first: Int!,
  $after: String,
  $sortKey: ProductCollectionSortKeys,
  $reverse: Boolean
) {
  node(id: $id) {
    ... on Collection {
      id
      title
      products(
        first: $first
        after: $after
        sortKey: $sortKey
        reverse: $reverse
      ) {
        pageInfo {
          hasNextPage
          endCursor
        }
        edges {
          node {
            id
            title
            images(first: 1) {
              edges { node { url } }
            }
            variants(first: 200) {
              edges {
                node {
                  id
                  title    
      availableForSale   
      quantityAvailable  
 
                  price { amount }
                  compareAtPrice { amount }
                  selectedOptions {
        name
        value
      }
                }
              }
            }
             collections(first: 200) {
            edges {
              node {
                title
                metafield(namespace: "custom", key: "mobile_app_setting_from_website") {
                  reference {
                    ... on Metaobject {
                      fields {
                        key
                        value
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
    }
  }
}
''';
