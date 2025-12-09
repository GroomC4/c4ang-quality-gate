@product
Feature: Product Deletion

  Background:
    * url baseUrls.product
    * def productPath = services.products

  @happy-path
  Scenario: [P1-PROD-04] Owner deletes product (soft delete)
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
        "categoryId": "123e4567-e89b-12d3-a456-426614174001",
        "name": "Product to Delete",
        "price": 10000,
        "stockQuantity": 50
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId

    # Delete product
    Given path productPath + '/' + productId
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    And request { "storeId": "#(storeId)" }
    When method PATCH
    Then status 200
    And match response.productId == productId
    And match response.deletedAt == '#notnull'

  @happy-path
  Scenario: [P1-PROD-04] Owner toggles product visibility (hide)
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
        "categoryId": "123e4567-e89b-12d3-a456-426614174001",
        "name": "Product to Hide",
        "price": 10000,
        "stockQuantity": 50
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId

    # Hide product
    Given path productPath + '/' + productId + '/hide'
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    And request { "storeId": "#(storeId)" }
    When method PATCH
    Then status 200
    And match response.productId == productId
    And match response.isHidden == true
