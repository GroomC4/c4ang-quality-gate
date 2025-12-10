@product
Feature: Product Registration

  Background:
    * url baseUrls.product
    * def productPath = services.products

  @happy-path
  Scenario: [P1-PROD-01] Owner registers product successfully
    # Setup: Create owner, login, and create store
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
        "categoryId": "00000000-0000-0000-0000-000000000001",
        "name": "Test Product",
        "price": 10000,
        "stockQuantity": 100,
        "description": "A test product for E2E testing"
      }
      """
    When method POST
    Then status 201
    And match response.productId == '#uuid'
    And match response.storeId == storeId
    And match response.name == 'Test Product'
    And match response.price == 10000
    And match response.stockQuantity == 100
    And match response.status == '#string'
    And match response.createdAt == '#notnull'

  @error-case
  Scenario: [P1-PROD-05] Register product with non-existent store fails
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken
    * def fakeStoreId = uuid()

    Given path productPath
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "storeId": "#(fakeStoreId)",
        "categoryId": "00000000-0000-0000-0000-000000000001",
        "name": "Orphan Product",
        "price": 5000,
        "stockQuantity": 50
      }
      """
    When method POST
    Then status 404

  @error-case
  Scenario: Customer cannot register product (403)
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def token = customer.accessToken

    # Need a valid storeId for request (will fail on auth before store validation)
    * def fakeStoreId = uuid()

    Given path productPath
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "storeId": "#(fakeStoreId)",
        "categoryId": "00000000-0000-0000-0000-000000000001",
        "name": "Customer Product",
        "price": 5000,
        "stockQuantity": 50
      }
      """
    When method POST
    Then status 403
