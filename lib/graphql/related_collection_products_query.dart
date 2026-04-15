const String relatedCollectionProductsQuery = r'''
query RelatedCollectionProducts($productId: ID!) {
  product(id: $productId) {
    collections(first: 5) {
      edges {
        node {
          id
          products(first: 15) {
            edges {
              node {
                id
                title
                descriptionHtml
                images(first: 1) {
                  edges {
                    node {
                      url
                    }
                  }
                }
                variants(first: 1) {
  edges {
    node {
      id
      title
      price { amount }
      compareAtPrice { amount }
      availableForSale
      quantityAvailable
      selectedOptions {
        name
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