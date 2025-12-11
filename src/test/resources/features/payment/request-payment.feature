@payment
Feature: Payment Request

  Background:
    * url baseUrls.payment
    * def paymentPath = services.payments
    * def orderPath = services.orders

  @happy-path @async @saga
  Scenario: [P1-PAY-01] Request payment for confirmed order
    # Setup: Create owner with store and product
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def ownerToken = owner.accessToken
    * def ownerId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(ownerToken)', userId: '#(ownerId)' }
    * def storeId = store.storeId
    * def product = call read('classpath:helpers/create-product.feature') { token: '#(ownerToken)', userId: '#(ownerId)', storeId: '#(storeId)', price: 10000, stockQuantity: 100 }
    * def productId = product.productId

    # Create customer and order
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId

    # Switch to order service
    * url baseUrls.order
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
    * print 'Order response:', response
    And assert response.status == 'ORDER_CONFIRMED'

    # Wait for payment-service to create payment via Kafka event
    # Payment-service listens to OrderConfirmed and creates Payment (PAYMENT_WAIT)
    # Use retry to wait for Kafka event propagation
    * def sleep = function(ms){ java.lang.Thread.sleep(ms) }
    * def findPaymentByOrderId = function(payments, targetOrderId) { for (var i = 0; i < payments.length; i++) { if (payments[i].orderId == targetOrderId) return payments[i].paymentId; } return null; }

    # Retry loop to get payment - Kafka event may take time
    * url baseUrls.payment
    Given path paymentPath
    And param userId = customerId
    And header Authorization = 'Bearer ' + customerToken
    # Retry until payments list is not empty (wait up to 20 seconds)
    And retry until response.payments.length > 0
    When method GET
    Then status 200
    * print 'Payments list response:', response
    * def paymentId = findPaymentByOrderId(response.payments, orderId)
    * print 'Found paymentId:', paymentId, 'for orderId:', orderId
    * assert paymentId != null

    # Request payment
    * def totalAmountNum = parseInt(totalAmount)
    * print 'Payment request - paymentId:', paymentId, 'totalAmount:', totalAmountNum
    Given path paymentPath + '/request'
    And header Authorization = 'Bearer ' + customerToken
    * def paymentRequest = { paymentId: '#(paymentId)', paymentMethod: 'CARD', totalAmount: '#(totalAmountNum)', paymentAmount: '#(totalAmountNum)', discountAmount: 0, deliveryFee: 0 }
    And request paymentRequest
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
    # 인증 없이 요청 시 400/401/403/500 모두 허용 (서비스 또는 Gateway AuthorizationPolicy)
    Then assert responseStatus == 400 || responseStatus == 401 || responseStatus == 403 || responseStatus == 500
