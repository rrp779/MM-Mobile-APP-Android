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

	String _normalizeStatusValue(dynamic raw) {
		final s = (raw ?? '').toString().trim();
		if (s.isEmpty) return '';
		final last = s.contains('.') ? s.split('.').last : s;
		return last.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
	}

	String _displayStatus(Map node) {
		final financial = _normalizeStatusValue(
			node['financialStatus'] ?? node['financial_status'] ?? node['displayFinancialStatus'],
		);
		final fulfillment = _normalizeStatusValue(
			node['fulfillmentStatus'] ?? node['fulfillment_status'] ?? node['displayFulfillmentStatus'],
		);
		final cancelReason = (node['cancelReason'] ?? node['cancel_reason'] ?? '').toString().trim();
		final cancelledAt = (node['cancelledAt'] ?? node['cancelled_at'] ?? '').toString().trim();

		if (cancelReason.isNotEmpty || cancelledAt.isNotEmpty) return 'Cancelled';
		if (financial == 'voided') return 'Cancelled';
		if (financial == 'refunded') return 'Refunded';
		if (financial == 'partially_refunded' || financial == 'partiallyrefunded') return 'Partially Refunded';
		// Shopify "fulfilled" typically means shipped; delivery is tracked separately.
		if (fulfillment == 'fulfilled') return 'Shipped';
		if (fulfillment == 'in_progress') return 'Shipped';
		if (fulfillment == 'partial' || fulfillment == 'partially_fulfilled') return 'Partially Shipped';
		if (financial == 'paid' || financial == 'partially_paid') return 'Confirmed';
		// Keep lifecycle simple: show Confirmed for new orders.
		if (financial == 'pending') return 'Confirmed';
		return 'Processing';
	}

	String _resolveDisplayStatus(Map node) {
		final fromApi = (node['displayStatus'] ?? node['display_status'] ?? '').toString().trim();
		if (fromApi.isNotEmpty) return fromApi;
		return _displayStatus(node);
	}

	String _formatOrderDate(dynamic processedAt) {
		try {
			final s = (processedAt ?? '').toString();
			final d = DateTime.parse(s);
			return DateFormat('EEE, d MMM').format(d);
		} catch (_) {
			return '-';
		}
	}

	Color _statusColor(String status) {
		switch (status.toLowerCase()) {
			case 'delivered':
				return Colors.green;
			case 'cancelled':
				return Colors.red;
			case 'refunded':
				return Colors.red;
			case 'partially refunded':
				return Colors.orange;
			case 'confirmed':
				return Colors.blue;
			case 'pending payment':
				return Colors.orange;
			case 'processing':
				return Colors.orange;
			default:
				return Colors.grey;
		}
	}

	Widget _statusBadge(String status) {
		final color = _statusColor(status);
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
			decoration: BoxDecoration(
				color: color.withOpacity(0.1),
				borderRadius: BorderRadius.circular(20),
				border: Border.all(color: color.withOpacity(0.4)),
			),
			child: Text(
				status.toUpperCase(),
				style: TextStyle(
					color: color,
					fontSize: 11,
					fontWeight: FontWeight.w700,
					letterSpacing: 0.5,
				),
			),
		);
	}


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
          orders(first: $limit, after: $after, sortKey: PROCESSED_AT, reverse: true) {

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
                      value {
                        ... on MoneyV2 {
                          amount
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
			if (result.hasException) {
				print('CustomerOrders GraphQL exception: ${result.exception}');
			}
			final edges = (result.data?['customer']?['orders']?['edges'] as List?) ?? const [];
			final names = edges
				.map((e) => (e is Map ? (e['node']?['name'] ?? '') : '').toString())
				.where((s) => s.isNotEmpty)
				.toList();
			print('CustomerOrders fetched ${edges.length} orders: $names');
		}

		setState(() {
			final fetchedEdges = (result.data?['customer']?['orders']?['edges'] as List?) ?? [];

			List merged = [];
			if (after == null || _orders == null) {
				merged = List.from(fetchedEdges);
			} else {
				merged = [..._orders!, ...fetchedEdges];
			}

			// De-duplicate by order id (Shopify GID)
			final byId = <String, dynamic>{};
			for (final e in merged) {
				if (e is! Map) continue;
				final id = (e['node']?['id'] ?? '').toString();
				if (id.isEmpty) continue;
				byId[id] = e;
			}

			final deduped = byId.values.toList();
			DateTime _safeParse(dynamic v) {
				try {
					final s = (v ?? '').toString();
					return DateTime.parse(s);
				} catch (_) {
					return DateTime.fromMillisecondsSinceEpoch(0);
				}
			}
			deduped.sort((a, b) {
				final dateA = _safeParse((a as Map)['node']?['processedAt']);
				final dateB = _safeParse((b as Map)['node']?['processedAt']);
				return dateB.compareTo(dateA);
			});

			_orders = deduped;

			_paginationLoading = false;
			_paginationInfo = result.data?['customer']?['orders']?['pageInfo'];
		});
	}

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) async {
			_getOrders();
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
																		_formatOrderDate(edge['node']['processedAt']),
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
																					final node = Map<String, dynamic>.from(edge['node'] as Map);
																					final displayStatus = _resolveDisplayStatus(node);
																					final textColor = _statusColor(displayStatus);

																					return Text(
																						displayStatus,
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
																					final node = Map<String, dynamic>.from(edge['node'] as Map);
																					final displayStatus = _resolveDisplayStatus(node);
																					return _statusBadge(displayStatus);
																				},
																			)

																		],
																	),

																	const SizedBox(height: 4),

																	Text(
																		"On ${_formatOrderDate(edge['node']['processedAt'])}",
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
