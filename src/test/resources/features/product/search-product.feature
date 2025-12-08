@product
Feature: Product Search

  Background:
    * url baseUrls.product
    * def productPath = services.products

  @happy-path
  Scenario: [P1-PROD-02] Search products by name
    # Setup: Create owner, store, and products
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken
    * def userId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(token)', userId: '#(userId)' }
    * def storeId = store.storeId

    # Create product
    Given path productPath
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    And request
      """
      {
        "storeId": "#(storeId)",
        "name": "Searchable Product ABC",
        "price": 15000,
        "stockQuantity": 50
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId

    # Search by name
    Given path productPath
    And param productName = 'Searchable'
    When method GET
    Then status 200
    And match response.products == '#array'
    And match response.totalElements == '#number'

  @happy-path
  Scenario: [P1-PROD-02] Get product by ID
    # Setup: Create owner, store, and product
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken
    * def userId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(token)', userId: '#(userId)' }
    * def storeId = store.storeId

    Given path productPath
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    And request
      """
      {
        "storeId": "#(storeId)",
        "name": "Specific Product",
        "price": 20000,
        "stockQuantity": 30,
        "description": "Product to retrieve by ID"
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId

    # Get by ID
    Given path productPath + '/' + productId
    When method GET
    Then status 200
    And match response.id == productId
    And match response.name == 'Specific Product'
    And match response.price == 20000
    And match response.stockQuantity == 30

  @happy-path
  Scenario: Get owner's products list
    # Setup: Create owner, store, and products
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken
    * def userId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(token)', userId: '#(userId)' }
    * def storeId = store.storeId

    # Create multiple products
    Given path productPath
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    And request { "storeId": "#(storeId)", "name": "Product 1", "price": 10000, "stockQuantity": 10 }
    When method POST
    Then status 201

    Given path productPath
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    And request { "storeId": "#(storeId)", "name": "Product 2", "price": 20000, "stockQuantity": 20 }
    When method POST
    Then status 201

    # Get owner's products
    Given path productPath + '/owner'
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    And param storeId = storeId
    When method GET
    Then status 200
    And match response.products == '#array'
    And match response.totalElements >= 2
