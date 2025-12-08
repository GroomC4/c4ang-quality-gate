@product
Feature: Product Update

  Background:
    * url baseUrls.product
    * def productPath = services.products

  @happy-path
  Scenario: [P1-PROD-03] Owner updates product info
    # Setup: Create owner, store, and product
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken
    * def userId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(token)', userId: '#(userId)' }
    * def storeId = store.storeId

    Given path productPath
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "storeId": "#(storeId)",
        "name": "Original Product",
        "price": 10000,
        "stockQuantity": 100
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId

    # Update product
    Given path productPath + '/' + productId
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "storeId": "#(storeId)",
        "name": "Updated Product",
        "price": 15000,
        "stockQuantity": 150,
        "description": "Updated description"
      }
      """
    When method PUT
    Then status 200
    And match response.productId == productId
    And match response.name == 'Updated Product'
    And match response.price == 15000
    And match response.stockQuantity == 150
    And match response.updatedAt == '#notnull'

  @error-case
  Scenario: Other owner cannot update product (403)
    # Setup: Create first owner's product
    * def owner1 = call read('classpath:helpers/create-owner-and-login.feature')
    * def token1 = owner1.accessToken
    * def userId1 = owner1.userId
    * def store1 = call read('classpath:helpers/create-store.feature') { token: '#(token1)', userId: '#(userId1)' }
    * def storeId1 = store1.storeId

    Given path productPath
    And header Authorization = 'Bearer ' + token1
    And request
      """
      {
        "storeId": "#(storeId1)",
        "name": "Owner1 Product",
        "price": 10000,
        "stockQuantity": 50
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId

    # Setup: Create second owner
    * def owner2 = call read('classpath:helpers/create-owner-and-login.feature')
    * def token2 = owner2.accessToken
    * def userId2 = owner2.userId

    # Try to update with different owner
    Given path productPath + '/' + productId
    And header Authorization = 'Bearer ' + token2
    And request
      """
      {
        "storeId": "#(storeId1)",
        "name": "Hijacked Product",
        "price": 99999,
        "stockQuantity": 1
      }
      """
    When method PUT
    Then status 403
