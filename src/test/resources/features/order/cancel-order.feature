@order
Feature: Order Cancellation

  Background:
    * url baseUrls.order
    * def orderPath = services.orders

  @happy-path @async @saga
  Scenario: [P1-ORDER-03] Customer cancels order successfully
    # Setup: Create owner with store and product
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def ownerToken = owner.accessToken
    * def ownerId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(ownerToken)', userId: '#(ownerId)' }
    * def storeId = store.storeId
    * def product = call read('classpath:helpers/create-product.feature') { token: '#(ownerToken)', userId: '#(ownerId)', storeId: '#(storeId)', stockQuantity: 100 }
    * def productId = product.productId

    # Setup: Create customer
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId

    # Create order
    Given path orderPath
    And header Authorization = 'Bearer ' + customerToken
    And request
      """
      {
        "storeId": "#(storeId)",
        "idempotencyKey": "#(uuid())",
        "items": [
          {
            "productId": "#(productId)",
            "productName": "Test Product",
            "quantity": 2,
            "unitPrice": 10000
          }
        ]
      }
      """
    When method POST
    Then status 201
    * def orderId = response.orderId

    # Wait for order to be confirmed first
    Given path orderPath + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.status == 'ORDER_CONFIRMED' || response.status == 'ORDER_FAILED'
    When method GET
    Then status 200

    # Cancel order
    Given path orderPath + '/' + orderId + '/cancel'
    And header Authorization = 'Bearer ' + customerToken
    And request
      """
      {
        "cancelReason": "E2E test cancellation"
      }
      """
    When method PATCH
    Then status 200
    And match response.orderId == orderId
    And match response.status contains 'CANCEL'
    And match response.cancelledAt == '#notnull'

  @error-case
  Scenario: Cannot cancel other user's order (403)
    # Setup: Create owner with store and product
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def ownerToken = owner.accessToken
    * def ownerId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(ownerToken)', userId: '#(ownerId)' }
    * def storeId = store.storeId
    * def product = call read('classpath:helpers/create-product.feature') { token: '#(ownerToken)', userId: '#(ownerId)', storeId: '#(storeId)' }
    * def productId = product.productId

    # Create order with customer1
    * def customer1 = call read('classpath:helpers/create-customer-and-login.feature')
    * def token1 = customer1.accessToken
    * def userId1 = customer1.userId

    Given path orderPath
    And header Authorization = 'Bearer ' + token1
    And request
      """
      {
        "storeId": "#(storeId)",
        "idempotencyKey": "#(uuid())",
        "items": [
          {
            "productId": "#(productId)",
            "productName": "Test",
            "quantity": 1,
            "unitPrice": 10000
          }
        ]
      }
      """
    When method POST
    Then status 201
    * def orderId = response.orderId

    # Try to cancel with customer2
    * def customer2 = call read('classpath:helpers/create-customer-and-login.feature')
    * def token2 = customer2.accessToken

    Given path orderPath + '/' + orderId + '/cancel'
    And header Authorization = 'Bearer ' + token2
    And request { "cancelReason": "Hijack attempt" }
    When method PATCH
    Then status 403
