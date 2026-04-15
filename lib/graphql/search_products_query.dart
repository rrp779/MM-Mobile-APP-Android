const String searchProductsQuery = r'''
query SearchProducts($query: String!) {
  products(first: 20, query: $query) {
    edges {
      node {
        id
        title
        descriptionHtml
        images(first: 5) {
          edges {
            node { url }
          }
        }
        variants(first: 5) {
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
''';
