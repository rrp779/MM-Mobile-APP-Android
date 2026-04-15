const String productsQuery = r'''
query Products {
$handle: String!,
  $first: Int!,
  $after: String,
  $sortKey: ProductCollectionSortKeys,
  $reverse: Boolean,
  $minPrice: Float,
  $maxPrice: Float
) {
  collection(handle: $handle) {
    title
    products(
      first: $first,
      after: $after,
      sortKey: $sortKey,
      reverse: $reverse,
      filters: {
        price: { min: $minPrice, max: $maxPrice }
      }
    ) {
      pageInfo {
        hasNextPage
        endCursor
      }
      edges {
        node {
          id
          title
          descriptionHtml

          images(first: 1) {
            edges {
              node { url }
            }
          }

          variants(first: 1) {
            edges {
              node {
                id
                 title   // 👈 ADD THIS
      availableForSale   // 👈 ADD THIS (CRITICAL)
      quantityAvailable  // 👈 ADD THIS
      inventoryPolicy  
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