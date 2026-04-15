import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// LOAD ADDRESSES
  Future<void> loadAddresses() async {

    final prefs = await SharedPreferences.getInstance();
    String? customer = prefs.getString("customer");


    if (customer == null) return;

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
      ),
    );

    final defaultAddress =
    result.data?["customer"]?["defaultAddress"]?["id"];

    final fetchedAddresses =
    result.data!["customer"]["addresses"]["edges"];

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
        variables: {
          "accessToken": accessToken,
          "addressId": addressId
        },
      ),
    );
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

          const Text(
            "Select Address",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
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