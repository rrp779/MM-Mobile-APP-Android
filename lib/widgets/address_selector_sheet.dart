import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../customer/customer_address_add.dart';

class AddressSelectorSheet extends StatefulWidget {

  final String? selectedId;

  const AddressSelectorSheet({
    super.key,
    this.selectedId,
  });

  @override
  State<AddressSelectorSheet> createState() => _AddressSelectorSheetState();
}

class _AddressSelectorSheetState extends State<AddressSelectorSheet> {

  List addresses = [];
  String? selectedId;
  bool loading = true;
  String? loadError;

  /// LOAD ADDRESSES
  Future<void> loadAddresses() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      loadError = null;
    });

    final prefs = await SharedPreferences.getInstance();
    String? customer = prefs.getString("customer");


    if (customer == null) {
      if (!mounted) return;
      setState(() {
        addresses = [];
        selectedId = null;
        loading = false;
        loadError = "Please login to select or add an address.";
      });
      return;
    }

    Map data = jsonDecode(customer);
    String accessToken = data["accessToken"];

    final client = GraphQLProvider.of(context).value;

    final result = await client.query(
      QueryOptions(
        document: gql(r'''
        query customer($accessToken: String!) {
          customer(customerAccessToken: $accessToken) {

            defaultAddress {
              id
            }

            addresses(first: 20) {
              edges {
                node {
                  id
                  name
                  address1
                  city
                  phone
                  zip
                }
              }
            }
          }
        }
      '''),
        variables: {"accessToken": accessToken},
        fetchPolicy: FetchPolicy.networkOnly,
        cacheRereadPolicy: CacheRereadPolicy.ignoreAll,
        errorPolicy: ErrorPolicy.all,
      ),
    );

    if (result.hasException) {
      if (!mounted) return;
      setState(() {
        addresses = [];
        selectedId = null;
        loading = false;
        loadError = "Could not load addresses. Please try again, or add a new address.";
      });
      return;
    }

    final defaultAddress =
    result.data?["customer"]?["defaultAddress"]?["id"];

    final fetchedAddresses =
    result.data?["customer"]?["addresses"]?["edges"] ?? [];

    String normalizeId(String id) {
      return id.split('/').last;
    }
    /// Ensure selectedId always has value
    String? initialSelected;

    if (widget.selectedId != null) {
      initialSelected = normalizeId(widget.selectedId!);
    } else if (defaultAddress != null) {
      initialSelected = normalizeId(defaultAddress);
    } else if (fetchedAddresses.isNotEmpty) {
      initialSelected =
          normalizeId(fetchedAddresses.first["node"]["id"]);
    }


    setState(() {
      addresses = fetchedAddresses;
      selectedId = initialSelected;
      loading = false;
    });
  }

  /// SET DEFAULT ADDRESS IN SHOPIFY
  Future<void> setDefaultAddress(String addressId) async {

    final prefs = await SharedPreferences.getInstance();
    String? customer = prefs.getString("customer");

    if (customer == null) return;

    Map data = jsonDecode(customer);
    String accessToken = data["accessToken"];

    final client = GraphQLProvider.of(context).value;

    await client.mutate(
      MutationOptions(
        document: gql(r'''
mutation customerDefaultAddressUpdate($accessToken: String!, $addressId: ID!) {
  customerDefaultAddressUpdate(customerAccessToken: $accessToken, addressId: $addressId) {
    customerUserErrors {
      code
      field
      message
    }
  }
}
'''),
        variables: {
          "accessToken": accessToken,
          "addressId": addressId
        },
      ),
    );
  }

  Future<void> openAddAddress() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerAddressAdd()),
    );
    await loadAddresses();
  }

  @override
  void initState() {
    super.initState();
    selectedId = widget.selectedId;
    loadAddresses();
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),

      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// HANDLE BAR
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Row(
            children: [
              const Expanded(
                child: Text(
                  "Select Address",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: openAddAddress,
                child: const Text(
                  "Add Address",
                  style: TextStyle(
                    color: Color(0xFFEA0180),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Expanded(
            child: (loadError != null)
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              loadError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA0180),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: openAddAddress,
                            child: const Text(
                              "Add Address",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : addresses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "No addresses found.",
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA0180),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: openAddAddress,
                              child: const Text(
                                "Add Address",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: addresses.length,
                        itemBuilder: (context, index) {

                String normalizeId(String id) {
                  return id.split('/').last;
                }
                final address = addresses[index]["node"];
                final isSelected =
                    normalizeId(selectedId ?? "") == normalizeId(address["id"]);

                return InkWell(

                  onTap: () async {

                    setState(() {
                      selectedId = normalizeId(address["id"]);
                    });

                    /// UPDATE DEFAULT ADDRESS
                    await setDefaultAddress(address["id"]);

                    Future.delayed(
                      const Duration(milliseconds: 200),
                          () {
                        Navigator.pop(context, address);
                      },
                    );
                  },

                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFEFF6)
                          : Colors.white,

                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFEA0180)
                            : Colors.grey.shade300,
                        width: 1.2,
                      ),
                    ),

                    child: Row(
                      children: [

                        /// ADDRESS TEXT
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [

                              Text(
                                address["name"] ?? "",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                "${address["address1"]}, ${address["city"]}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        /// RADIO STYLE
                        AnimatedContainer(
                          duration:
                          const Duration(milliseconds: 200),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFEA0180)
                                  : Colors.grey,
                              width: 2,
                            ),
                            color: isSelected
                                ? const Color(0xFFEA0180)
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
