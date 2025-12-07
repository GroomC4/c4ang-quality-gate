@payment @saga
Feature: Payment Request

  Background:
    * url baseUrl
    * def paymentPath = services.payments
    * def orderPath = services.orders

  @happy-path @async
  Scenario: [P1-PAY-01] Request payment for confirmed order
    # Setup: Create owner with store and product
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def ownerToken = owner.accessToken
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(ownerToken)' }
    * def storeId = store.storeId
    * def product = call read('classpath:helpers/create-product.feature') { token: '#(ownerToken)', storeId: '#(storeId)', price: 10000, stockQuantity: 100 }
    * def productId = product.productId

    # Create customer and order
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken

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
    * def totalAmount = response.totalAmount

    # Wait for order confirmation
    Given path orderPath + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.status == 'ORDER_CONFIRMED' || response.status == 'ORDER_FAILED'
    When method GET
    Then status 200
    And assert response.status == 'ORDER_CONFIRMED'

    # Request payment
    * def paymentId = uuid()
    Given path paymentPath + '/request'
    And header Authorization = 'Bearer ' + customerToken
    And request
      """
      {
        "paymentId": "#(paymentId)",
        "paymentMethod": "CARD",
        "totalAmount": #(totalAmount),
        "paymentAmount": #(totalAmount),
        "discountAmount": 0,
        "deliveryFee": 0
      }
      """
    When method POST
    Then status 201
    And match response.paymentId == paymentId
    And match response.status == '#string'

  @error-case
  Scenario: Payment request without authentication fails
    Given path paymentPath + '/request'
    And request
      """
      {
        "paymentId": "#(uuid())",
        "paymentMethod": "CARD",
        "totalAmount": 10000,
        "paymentAmount": 10000,
        "discountAmount": 0,
        "deliveryFee": 0
      }
      """
    When method POST
    Then status 401
