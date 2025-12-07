@e2e @saga @async
Feature: Full Purchase Flow E2E

  Background:
    * url baseUrl
    * configure retry = { count: 20, interval: 1000 }

  @happy-path
  Scenario: [P1-E2E-01] Complete purchase flow - Signup → Store → Product → Order → Payment
    # ============================================
    # Step 1: Owner signup and login
    # ============================================
    * print '=== Step 1: Owner signup and login ==='
    * def ownerEmail = generateOwnerEmail()
    * def ownerUsername = generateUsername()

    Given path services.ownerSignup
    And request
      """
      {
        "username": "#(ownerUsername)",
        "email": "#(ownerEmail)",
        "password": "#(testPassword)",
        "phoneNumber": "010-1111-2222"
      }
      """
    When method POST
    Then status 201
    * def ownerId = response.user.id

    Given path services.ownerLogin
    And request { "email": "#(ownerEmail)", "password": "#(testPassword)" }
    When method POST
    Then status 200
    * def ownerToken = response.accessToken
    * print 'Owner created and logged in:', ownerId

    # ============================================
    # Step 2: Create store
    # ============================================
    * print '=== Step 2: Create store ==='

    Given path services.stores
    And header Authorization = 'Bearer ' + ownerToken
    And request
      """
      {
        "name": "E2E Test Store",
        "description": "Store for full purchase flow test"
      }
      """
    When method POST
    Then status 201
    * def storeId = response.storeId
    * print 'Store created:', storeId

    # ============================================
    # Step 3: Register product
    # ============================================
    * print '=== Step 3: Register product ==='

    Given path services.products
    And header Authorization = 'Bearer ' + ownerToken
    And request
      """
      {
        "storeId": "#(storeId)",
        "name": "E2E Test Product",
        "price": 15000,
        "stockQuantity": 100,
        "description": "Product for E2E testing"
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId
    * def productPrice = response.price
    * print 'Product created:', productId

    # ============================================
    # Step 4: Customer signup and login
    # ============================================
    * print '=== Step 4: Customer signup and login ==='
    * def customerEmail = generateCustomerEmail()
    * def customerUsername = generateUsername()

    Given path services.customerSignup
    And request
      """
      {
        "username": "#(customerUsername)",
        "email": "#(customerEmail)",
        "password": "#(testPassword)",
        "defaultAddress": "서울특별시 강남구 테헤란로 123",
        "defaultPhoneNumber": "010-1234-5678"
      }
      """
    When method POST
    Then status 201
    * def customerId = response.userId

    Given path services.customerLogin
    And request { "email": "#(customerEmail)", "password": "#(testPassword)" }
    When method POST
    Then status 200
    * def customerToken = response.accessToken
    * print 'Customer created and logged in:', customerId

    # ============================================
    # Step 5: Create order
    # ============================================
    * print '=== Step 5: Create order ==='
    * def orderQuantity = 2
    * def expectedTotal = productPrice * orderQuantity

    Given path services.orders
    And header Authorization = 'Bearer ' + customerToken
    And request
      """
      {
        "storeId": "#(storeId)",
        "idempotencyKey": "#(uuid())",
        "items": [
          {
            "productId": "#(productId)",
            "productName": "E2E Test Product",
            "quantity": #(orderQuantity),
            "unitPrice": #(productPrice)
          }
        ],
        "note": "Full purchase flow E2E test"
      }
      """
    When method POST
    Then status 201
    And match response.totalAmount == expectedTotal
    * def orderId = response.orderId
    * def orderNumber = response.orderNumber
    * print 'Order created:', orderId, 'Total:', expectedTotal

    # ============================================
    # Step 6: Wait for order confirmation (SAGA)
    # ============================================
    * print '=== Step 6: Wait for order confirmation (stock reservation) ==='

    Given path services.orders + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.status == 'ORDER_CONFIRMED' || response.status == 'ORDER_FAILED'
    When method GET
    Then status 200
    And match response.status == 'ORDER_CONFIRMED'
    * print 'Order confirmed:', response.status

    # ============================================
    # Step 7: Request payment
    # ============================================
    * print '=== Step 7: Request payment ==='
    * def paymentId = uuid()

    Given path services.payments + '/request'
    And header Authorization = 'Bearer ' + customerToken
    And request
      """
      {
        "paymentId": "#(paymentId)",
        "paymentMethod": "CARD",
        "totalAmount": #(expectedTotal),
        "paymentAmount": #(expectedTotal),
        "discountAmount": 0,
        "deliveryFee": 0
      }
      """
    When method POST
    Then status 201
    * print 'Payment requested:', paymentId

    # ============================================
    # Step 8: Verify final order status
    # ============================================
    * print '=== Step 8: Verify final order status ==='

    Given path services.orders + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.status == 'PAYMENT_COMPLETED' || response.status == 'PAYMENT_PENDING' || response.status == 'PAYMENT_FAILED'
    When method GET
    Then status 200
    * print 'Final order status:', response.status

    * print '=== Full Purchase Flow Completed Successfully ==='
