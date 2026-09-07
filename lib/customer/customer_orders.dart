import 'dart:convert' show jsonDecode;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'customer_order_details.dart';
import '../widgets/main_bottom_bar.dart';
import '../widgets/app_icon.dart';


class CustomerOrders extends StatefulWidget {
	const CustomerOrders({super.key});

	@override
	State<CustomerOrders> createState() => _CustomerOrdersState();
}

class _CustomerOrdersState extends State<CustomerOrders> {
	final _scaffoldKey = GlobalKey<ScaffoldState>();
	final ScrollController _listViewController = ScrollController();
	List? _orders;
	bool _paginationLoading = false;
	Map? _paginationInfo;
	int selectedIndex = 4;


	void _handleNavigation(int index) {
		switch (index) {
			case 0:
				Navigator.pushReplacementNamed(context, '/home');
				break;
			case 1:
				break;
			case 2:
				Navigator.pushReplacementNamed(context, '/brand');
				break;
			case 3:
				Navigator.pushReplacementNamed(context, '/cart');
				break;
			case 4:
				Navigator.pushReplacementNamed(context, '/profile');
				break;
		}
	}



	Future<void> _getOrders({int limit = 24, String? after}) async {
		final client = GraphQLProvider.of(context).value;

		final prefs = await SharedPreferences.getInstance();
		String? customerEncoded = prefs.getString('customer');

		if (customerEncoded == null) {
			return;
		}

		Map customer = jsonDecode(customerEncoded);
		String accessToken = customer['accessToken'];

		final result = await client.query(
			QueryOptions(
				document: gql(r'''
      query customer($accessToken: String!, $limit: Int, $after: String) {
        customer(customerAccessToken: $accessToken) {
          orders(first: $limit, after: $after) {

            edges {
              node {
                id
                name
                processedAt

                subtotalPriceV2 {
                  amount
                  currencyCode
                }

                totalShippingPriceV2 {
                  amount
                  currencyCode
                }

                totalPriceV2 {
                  amount
                  currencyCode
                }

                discountApplications(first: 10) {
                  edges {
                    node {
                      __typename
                      ... on DiscountCodeApplication {
                        code
                      }
                      ... on AutomaticDiscountApplication {
                        title
                      }
                      value {
                        ... on MoneyV2 {
                          amount
                        }
                        ... on PricingPercentageValue {
                          percentage
                        }
                      }
                    }
                  }
                }

                shippingAddress {
                  name
                  address1
                  city
                  province
                  country
                  zip
                  phone
                }

                financialStatus
                fulfillmentStatus
                canceledAt
                cancelReason
                customerUrl

                lineItems(first: 5) {
                  edges {
                    node {
                      title
                      quantity

                      variant {
                        price {
                          amount
                        }

                        compareAtPrice {
                          amount
                        }

                        image {
                          url
                        }

                        selectedOptions {
                          name
                          value
                        }

                        product {
                          id
                          featuredImage {
                            url
                          }
                        }
                      }
                    }
                  }
                }

              }
            }

            pageInfo {
              endCursor
              hasNextPage
            }

          }
        }
      }
    '''),
				variables: {
					'accessToken': accessToken,
					'limit': limit,
					'after': after,
				},
			),
		);

		if (kDebugMode) {
			print(result);
		}

		setState(() {
			if (after == null) {
				_orders = result.data!['customer']['orders']['edges'];
			} else {
				List orders = result.data!['customer']['orders']['edges'];

				orders.sort((a, b) {
					DateTime dateA = DateTime.parse(a['node']['processedAt']);
					DateTime dateB = DateTime.parse(b['node']['processedAt']);

					return dateB.compareTo(dateA); // 🔥 latest first
				});

				_orders = orders;
			}

			_paginationLoading = false;
			_paginationInfo = result.data!['customer']['orders']['pageInfo'];
		});

		_checkAndOpenSpecificOrder();
	}

	bool _hasAutoNavigated = false;

	void _checkAndOpenSpecificOrder() {
		if (_hasAutoNavigated || _orders == null || !mounted) return;

		final args = ModalRoute.of(context)?.settings.arguments;
		if (args is Map) {
			final targetNumber = args['orderNumber']?.toString().replaceAll(RegExp(r'[^0-9]'), '');
			final targetId = args['orderId']?.toString().replaceAll(RegExp(r'[^0-9]'), '');

			if ((targetNumber != null && targetNumber.isNotEmpty) || (targetId != null && targetId.isNotEmpty)) {
				for (final edge in _orders!) {
					final node = edge['node'];
					if (node == null) continue;

					final orderName = node['name']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
					final orderId = node['id']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';

					if ((targetNumber != null && targetNumber.isNotEmpty && orderName == targetNumber) ||
							(targetId != null && targetId.isNotEmpty && orderId.contains(targetId))) {
						_hasAutoNavigated = true;
						WidgetsBinding.instance.addPostFrameCallback((_) {
							if (mounted) {
								Navigator.push(
									context,
									MaterialPageRoute(
										builder: (_) => OrderDetailsPage(order: node),
									),
								);
							}
						});
						break;
					}
				}
			}
		}
	}

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) async {
			await _getOrders();
		});
  }

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			key: _scaffoldKey,
			backgroundColor: Colors.white, // add this
			appBar: AppBar(
				backgroundColor: Colors.white,
				elevation: 0,
				title: const Text(
					'My Orders',
					style: TextStyle(
						fontSize: 18,
						fontWeight: FontWeight.w600,
						color: Colors.black,
					),
				),
				/// BACK ICON
				leading: IconButton(
					padding: EdgeInsets.zero,
					constraints: const BoxConstraints(),
					icon: const SizedBox(
						width: 22,
						height: 22,
						child: AppIcon(
							isActive: false,
							outlinePath: 'assets/icons/ArrowLeft.svg',
							filledPath: 'assets/icons/ArrowLeft.svg',
						),
					),
					onPressed: () {
						Navigator.pop(context);
					},
				),
			),
			body: _orders == null 
				? const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading, please wait',))
				: _orders!.isEmpty
					? Center(
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								const Icon(Icons.sentiment_dissatisfied, size: 28, color: Colors.grey,),
								const SizedBox(height: 12),
								const Text('No orders found!'),
								const SizedBox(height: 16),
								ElevatedButton(
									onPressed: () async {
										await Future.delayed(const Duration(milliseconds: 200));
										if (context.mounted) {
											Navigator.of(context).pop();
										}
									},
									child: const Text('Continue Shopping'),
								)
							],
						)
					)
					: NotificationListener<ScrollEndNotification>(
						onNotification: (scrollEnd) {
							if (scrollEnd.metrics.atEdge) {
								bool isTop = scrollEnd.metrics.pixels == 0;
								
								if (isTop) { return false; }

								if (_paginationInfo != null && _paginationInfo!['hasNextPage']) {
									setState(() {
									  	_paginationLoading = true;
									});
									_getOrders(after: _paginationInfo!['endCursor']);
								}
							}
							return false;
						},
						child: Column(
							children: [
								Expanded(
									child: ListView(
										controller: _listViewController,
										padding: const EdgeInsets.fromLTRB(6, 8, 6, 48),
										children: [
											for (dynamic edge in _orders!)
												Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [

														/// ORDER ID + DATE (OUTSIDE CARD)
														Padding(
															padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
															child: Row(
																mainAxisAlignment: MainAxisAlignment.spaceBetween,
																children: [
																	Text(
																		"Order ID:\n${edge['node']['name']}",
																		style: const TextStyle(
																			fontSize: 12,
																			color: Colors.black,
																			height: 1.5,
																			fontWeight: FontWeight.bold,
																		),
																	),
																	Text(
																		DateFormat('EEE, d MMM')
																				.format(DateTime.parse(edge['node']['processedAt'])),
																		style: const TextStyle(color: Colors.black,fontSize: 12, ),
																	)
																],
															),
														),

														/// ORDER CARD
														Container(
															margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
															padding: const EdgeInsets.all(12),
															decoration: BoxDecoration(
																color: Colors.white,
																borderRadius: BorderRadius.circular(12),
																border: Border.all(
																	color: Colors.grey.shade300,
																),
															),
															child: Column(
																crossAxisAlignment: CrossAxisAlignment.start,
																children: [

																	/// STATUS
																	Row(
																		mainAxisAlignment: MainAxisAlignment.spaceBetween,
																		children: [

																			Builder(
																				builder: (context) {

																					final canceledAt = edge['node']['canceledAt'];
																					final fulfillmentStatus = edge['node']['fulfillmentStatus'] ?? "";

																					String text = "Processing";
																					Color textColor = Colors.orange;

																					if (canceledAt != null) {
																						text = "Cancelled";
																						textColor = Colors.red;
																					}
																					else if (fulfillmentStatus == "FULFILLED") {
																						text = "Delivered";
																						textColor = Colors.green;
																					}
																					else if (fulfillmentStatus == "PARTIAL") {
																						text = "Partially Delivered";
																						textColor = Colors.blue;
																					}
																					else if (fulfillmentStatus == "UNFULFILLED") {
																						text = "Processing";
																						textColor = Colors.orange;
																					}

																					return Text(
																						text,
																						style: TextStyle(
																							fontSize: 14,
																							fontWeight: FontWeight.bold,
																							color: textColor,
																						),
																					);
																				},
																			),

																			Builder(
																				builder: (context) {

																					final financialStatus = edge['node']['financialStatus'] ?? "";

																					Color bgColor = Colors.orange.shade50;
																					Color textColor = Colors.orange;

																					if (financialStatus == "PAID") {
																						bgColor = Colors.green.shade50;
																						textColor = Colors.green;
																					} else if (financialStatus == "REFUNDED") {
																						bgColor = Colors.blue.shade50;
																						textColor = Colors.blue;
																					} else if (financialStatus == "PARTIALLY_PAID") {
																						bgColor = Colors.red.shade50;
																						textColor = Colors.red;
																					}

																					return Container(
																						padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
																						decoration: BoxDecoration(
																							color: bgColor,
																							borderRadius: BorderRadius.circular(20),
																						),
																						child: Text(
																							financialStatus.replaceAll("_", " "),
																							style: TextStyle(
																								color: textColor,
																								fontSize: 10,
																								fontWeight: FontWeight.w500,
																							),
																						),
																					);
																				},
																			)

																		],
																	),

																	const SizedBox(height: 4),

																	Text(
																		"On ${DateFormat('EEE, d MMM').format(DateTime.parse(edge['node']['processedAt']))}",
																		style: const TextStyle(color: Colors.grey),
																	),

																	const SizedBox(height: 12),

																	Column(
																		children: [
																			for (var item in edge['node']['lineItems']['edges']) ...[
																				Container(
																					margin: const EdgeInsets.only(bottom: 5),
																					padding: const EdgeInsets.all(10),
																					decoration: BoxDecoration(
																						borderRadius: BorderRadius.circular(10),
																						border: Border.all(color: Colors.grey.shade300),
																					),
																					child: Row(
																						children: [

																							/// PRODUCT IMAGE
																							ClipRRect(
																								borderRadius: BorderRadius.circular(8),
																								child: Image.network(
																									item['node']?['variant']?['image']?['url'] ?? "",
																									height: 60,
																									width: 60,
																									fit: BoxFit.cover,
																									errorBuilder: (context, error, stackTrace) {
																										return Container(
																											height: 60,
																											width: 60,
																											color: Colors.grey.shade200,
																											child: const Icon(Icons.image),
																										);
																									},
																								),
																							),

																							const SizedBox(width: 12),

																							/// PRODUCT DETAILS
																							Expanded(
																								child: Column(
																									crossAxisAlignment: CrossAxisAlignment.start,
																									children: [

																										/// PRODUCT TITLE
																										Text(
																											item['node']?['title'] ?? "Product",
																											maxLines: 2,
																											overflow: TextOverflow.ellipsis,
																											style: const TextStyle(
																												fontSize: 12,
																												fontWeight: FontWeight.w400,
																											),
																										),

																										/// VARIANT OPTIONS
																										if (item['node']?['variant']?['selectedOptions'] != null &&
																												item['node']['variant']['selectedOptions'].isNotEmpty)
																											Padding(
																												padding: const EdgeInsets.only(top: 3),
																												child: Wrap(
																													spacing: 6,
																													children: [
																														for (var option in item['node']['variant']['selectedOptions'])
																															if (option['value'] != null &&
																																	option['value'] != "" &&
																																	option['value'] != "Default Title")
																																Container(
																																	padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
																																	decoration: BoxDecoration(
																																		color: Colors.grey.shade200,
																																		borderRadius: BorderRadius.circular(20),
																																	),
																																	child: Text(
																																		option['value'],
																																		style: const TextStyle(
																																			fontSize: 10,
																																			color: Colors.black87,
																																		),
																																	),
																																)
																													],
																												),
																											),
																									],
																								)
																							),

																						],
																					),
																				),

																			]
																		],
																	),
																	/// VIEW DETAILS BUTTON
																	Align(
																		alignment: Alignment.centerRight,
																		child: OutlinedButton(
																			onPressed: () {
																				Navigator.push(
																					context,
																					MaterialPageRoute(
																						builder: (context) => OrderDetailsPage(
																							order: edge['node'],
																						),
																					),
																				);
																			},
																			style: OutlinedButton.styleFrom(
																				foregroundColor: Colors.pink, // text color
																				side: const BorderSide(color: Colors.pink), // border color
																				shape: RoundedRectangleBorder(
																					borderRadius: BorderRadius.circular(20), // round shape
																				),
																				minimumSize: const Size(0, 30), // height = 36
																				padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
																			),
																			child: const Text(
																				"View Details",
																				style: TextStyle(
																					fontSize: 11,
																					fontWeight: FontWeight.w600,
																				),
																			),
																		),
																	)
																],
															),
														),

														const SizedBox(height: 12),
														SizedBox(
															width: double.infinity,
															child: Row(
																mainAxisAlignment: MainAxisAlignment.spaceBetween,
																children: List.generate(
																	100,
																			(index) => Container(
																		width: 2,
																		height: 2,
																		decoration: BoxDecoration(
																			color: const Color(0xFFDADADA),
																			shape: BoxShape.circle,
																		),
																	),
																),
															),
														),
														const SizedBox(height: 12),
													],

												),

										],
									)
								),
								if (_paginationLoading)
									const LinearProgressIndicator(semanticsLabel: 'Loading',)
							]
						)
					),
			bottomNavigationBar: MainBottomBar(
				selectedIndex: selectedIndex,
				onItemSelected: (index) {
					setState(() {
						selectedIndex = index;
					});
					_handleNavigation(index);
				},
			),
		);
	}
}
