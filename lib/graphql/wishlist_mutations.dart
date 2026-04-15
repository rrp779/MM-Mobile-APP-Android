const String updateWishlistMutation = r'''
mutation UpdateWishlist(
  $customerAccessToken: String!,
  $wishlist: String!
) {
  customerUpdate(
    customerAccessToken: $customerAccessToken,
    customer: {
      metafields: [
        {
          namespace: "wishlist"
          key: "products"
          type: "list.single_line_text_field"
          value: $wishlist
        }
      ]
    }
  ) {
    customer {
      id
    }
    customerUserErrors {
      message
    }
  }
}
''';
