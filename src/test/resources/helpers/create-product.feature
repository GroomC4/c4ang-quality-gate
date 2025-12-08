@ignore
Feature: Create Product Helper

  Scenario: Create product with owner token and store
    * def args = __arg || {}
    * def token = args.token
    * def storeId = args.storeId
    * def productName = args.name || 'Test Product ' + uuid().substring(0, 8)
    * def price = args.price || 10000
    * def stockQuantity = args.stockQuantity || 100

    Given url baseUrls.product
    And path services.products
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "storeId": "#(storeId)",
        "name": "#(productName)",
        "price": #(price),
        "stockQuantity": #(stockQuantity),
        "description": "Test product for E2E"
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId
    * def product = response
