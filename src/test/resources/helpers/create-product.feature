@ignore
Feature: Create Product Helper

  Scenario: Create product with owner token and store
    * url baseUrl
    * def token = __arg.token
    * def storeId = __arg.storeId
    * def productName = __arg.name || 'Test Product ' + uuid().substring(0, 8)
    * def price = __arg.price || 10000
    * def stockQuantity = __arg.stockQuantity || 100

    Given path services.products
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
