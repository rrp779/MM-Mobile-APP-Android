const String relatedProductsQuery = r'''
query RelatedProducts($productId: ID!) {

  productRecommendations(productId: $productId) {
    id
    title
    descriptionHtml
    images(first: 5) {
      edges {
        node { url }
      }
    }
    variants(first: 20) {
  edges {
    node {
      id
      title
      availableForSale
      quantityAvailable
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
    }
  }
}
  }

  products(first: 10) {
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
        variants(first: 20) {
  edges {
    node {
      id
      title
      availableForSale
      quantityAvailable
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
    }
  }
}
      }
    }
  }

}
''';