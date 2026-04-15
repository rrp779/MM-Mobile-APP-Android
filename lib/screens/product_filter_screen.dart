import 'package:flutter/material.dart';
import '../models/collection.dart';

class FilterScreen extends StatefulWidget {
  final Set<String> selectedBrands;
  final List<CollectionModel> brands;
  final Set<String> selectedPrices;

  const FilterScreen({
    super.key,
    required this.selectedBrands,
    required this.selectedPrices,
    required this.brands,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  int selectedIndex = 0;

  final List<String> filters = [
    "Brand",
    "Price",
  ];
  late Set<String> selectedBrands;
  late Set<String> selectedPrices;
  late List<CollectionModel> filteredBrands;

  TextEditingController _searchController = TextEditingController();
  String searchText = "";

  @override
  void initState() {
    super.initState();

    selectedBrands = Set.from(widget.selectedBrands);
    filteredBrands = List.from(widget.brands);
    selectedPrices = Set.from(widget.selectedPrices);

  }


  final List<Map<String, dynamic>> priceRanges = [
    {"label": "Rs. 0 - Rs. 499", "min": 0.0, "max": 499.0},
    {"label": "Rs. 500 - Rs. 999", "min": 500.0, "max": 999.0},
    {"label": "Rs. 1000 - Rs. 1999", "min": 1000.0, "max": 1999.0},
  ];

  /// 🔍 SEARCH
  void _searchBrand(String value) {
    searchText = value.toLowerCase();

    if (searchText.isEmpty) {
      setState(() {
        filteredBrands = List.from(widget.brands);
      });
      return;
    }


    setState(() {
      filteredBrands = widget.brands.where((b) {
        final name = (b.title ?? "").toLowerCase();
        return name.contains(searchText);
      }).toList();
    });
  }

  Widget _buildBrandList() {
    if (filteredBrands.isEmpty) {
      return const Center(child: Text("No brands found"));
    }

    return ListView.builder(
      itemCount: filteredBrands.length,
      itemBuilder: (_, i) {
        final brand = filteredBrands[i];
        final name = brand.title;
        final isSelected = selectedBrands.contains(name);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
              Text(brand.mobileDescription ?? '0'),
            ],
          ),
          trailing: Checkbox(
            value: isSelected,
            activeColor: const Color(0xFFEA0180),
            onChanged: (_) {
              setState(() {
                if (isSelected) {
                  selectedBrands.remove(name);
                } else {
                  selectedBrands.add(name);
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildPriceList() {
    return ListView(
      children: priceRanges.map((range) {
        final label = range["label"];
        final isSelected = selectedPrices.contains(label);

        return ListTile(
          title: Text(label),
          trailing: Checkbox(
            value: isSelected,
            activeColor: const Color(0xFFEA0180),
            onChanged: (_) {
              setState(() {
                if (isSelected) {
                  selectedPrices.remove(label);
                } else {
                  selectedPrices.add(label);
                }
              });
            },
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      /// 🔹 APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Filters",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                selectedBrands.clear();
                selectedPrices.clear();
                filteredBrands = List.from(widget.brands);
              });
            },
            child: const Text("Reset"),
          )
        ],
      ),

      /// 🔹 BODY
      body: Row(
        children: [
          /// 🔥 LEFT MENU
          Container(
            width: 120,
            color: Colors.grey.shade100,
            child: ListView.builder(
              itemCount: filters.length,
              itemBuilder: (_, i) {
                final selected = selectedIndex == i;

                return GestureDetector(
                  onTap: () {
                    setState(() => selectedIndex = i);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: selected ? Colors.white : Colors.transparent,
                    child: Text(
                      filters[i],
                      style: TextStyle(
                        fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                        color: selected
                            ? const Color(0xFFEA0180)
                            : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          /// 🔥 RIGHT SIDE
          Expanded(
            child: Column(
              children: [

                /// 🔍 SEARCH
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchBrand,
                      decoration: InputDecoration(
                        hintText: "Search brand...",
                        border: InputBorder.none,

                        prefixIcon: const Icon(Icons.search, color: Colors.grey),

                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _searchBrand("");
                          },
                        )
                            : null,

                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                /// 🔥 BRAND LIST

                Expanded(
                  child: selectedIndex == 0
                      ? _buildBrandList()
                      : _buildPriceList(),
                ),

                /// 🔥 BUTTONS
      SafeArea(
        top: false, // 👈 important (only apply bottom safe area)
        child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black, // ✅ TEXT COLOR
                            side: const BorderSide(color: Colors.black), // ✅ BORDER COLOR
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA0180), // ✅ BG
                            foregroundColor: Colors.white, // ✅ TEXT
                          ),
                          onPressed: () {
                            Navigator.pop(context, {
                              "brands": selectedBrands,
                              "prices": selectedPrices,
                            });
                          },
                          child: const Text("Apply"),
                        ),
                      ),
                    ],
                  ),
                )
      )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

