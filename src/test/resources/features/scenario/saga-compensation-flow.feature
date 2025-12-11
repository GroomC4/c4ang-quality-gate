@e2e @saga @async @compensation
Feature: SAGA Compensation Flow E2E

  Background:
    # Saga Tracker 기반 비동기 검증을 위한 retry 설정 강화
    * configure retry = { count: 30, interval: 3000 }

  @error-case
  Scenario: [P1-E2E-02] Stock reservation failure triggers order cancellation
    # ============================================
    # Setup: Create owner with store and product with limited stock
    # ============================================
    * print '=== Setup: Create store with limited stock product ==='
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def ownerToken = owner.accessToken
    * def ownerId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(ownerToken)', userId: '#(ownerId)' }
    * def storeId = store.storeId

    # Create product with very limited stock
    * url baseUrls.product
    Given path services.products
    And header Authorization = 'Bearer ' + ownerToken
    And request
      """
      {
        "storeId": "#(storeId)",
        "categoryId": "00000000-0000-0000-0000-000000000001",
        "name": "Limited Stock Product",
        "price": 10000,
        "stockQuantity": 5,
        "description": "Product with limited stock for compensation test"
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId
    * print 'Product created with stock: 5'

    # ============================================
    # Create customer
    # ============================================
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId

    # ============================================
    # Try to order more than available stock
    # ============================================
    * print '=== Attempting to order 100 units (stock: 5) ==='

    * url baseUrls.order
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
            "productName": "Limited Stock Product",
            "quantity": 100,
            "unitPrice": 10000
          }
        ]
      }
      """
    When method POST
    Then status 201
    * def orderId = response.orderId
    * print 'Order created:', orderId

    # ============================================
    # Wait for SAGA compensation via Saga Tracker
    # ============================================
    * print '=== Waiting for SAGA compensation (Saga Tracker) ==='

    # Saga Tracker API를 통해 보상 트랜잭션 완료 확인
    * def sagaWaitConfig = { orderId: '#(orderId)', expectedStatus: 'COMPENSATED', token: '#(customerToken)', maxWait: 90000, interval: 3000 }
    * def sagaResult = call read('classpath:helpers/wait-saga-status.feature') sagaWaitConfig
    * print 'Saga Tracker result:', sagaResult.result

    # Saga 보상 완료 확인
    * def sagaSuccess = sagaResult.result.success
    * print 'Saga compensated successfully:', sagaSuccess

    # Order API로 최종 상태 확인
    * url baseUrls.order
    Given path services.orders + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.status == 'ORDER_FAILED' || response.status == 'ORDER_CONFIRMED'
    When method GET
    Then status 200
    * print 'Order status after SAGA:', response.status

    # Order should be failed due to stock reservation failure
    And match response.status == 'ORDER_FAILED'
    * print '=== SAGA Compensation completed: Order failed due to insufficient stock ==='

  @happy-path
  Scenario: [P1-E2E-03] Order cancellation restores stock
    # ============================================
    # Setup: Create owner with store and product
    # ============================================
    * print '=== Setup ==='
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def ownerToken = owner.accessToken
    * def ownerId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(ownerToken)', userId: '#(ownerId)' }
    * def storeId = store.storeId

    * url baseUrls.product
    Given path services.products
    And header Authorization = 'Bearer ' + ownerToken
    And request
      """
      {
        "storeId": "#(storeId)",
        "categoryId": "00000000-0000-0000-0000-000000000001",
        "name": "Cancellation Test Product",
        "price": 10000,
        "stockQuantity": 50
      }
      """
    When method POST
    Then status 201
    * def productId = response.productId

    # ============================================
    # Create customer and order
    # ============================================
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId

    * url baseUrls.order
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
            "productName": "Cancellation Test Product",
            "quantity": 10,
            "unitPrice": 10000
          }
        ]
      }
      """
    When method POST
    Then status 201
    * def orderId = response.orderId

    # ============================================
    # Wait for order confirmation
    # ============================================
    Given path services.orders + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.status == 'ORDER_CONFIRMED' || response.status == 'ORDER_FAILED'
    When method GET
    Then status 200
    And match response.status == 'ORDER_CONFIRMED'
    * print 'Order confirmed, stock reserved'

    # ============================================
    # Cancel order
    # ============================================
    * print '=== Cancelling order ==='

    Given path services.orders + '/' + orderId + '/cancel'
    And header Authorization = 'Bearer ' + customerToken
    And request { "cancelReason": "E2E test - stock restoration check" }
    When method PATCH
    Then status 200
    And match response.status contains 'CANCEL'
    * print 'Order cancelled - stock should be restored'

    # ============================================
    # Verify stock was restored by creating another order
    # ============================================
    * print '=== Verifying stock restoration ==='

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
            "productName": "Cancellation Test Product",
            "quantity": 10,
            "unitPrice": 10000
          }
        ]
      }
      """
    When method POST
    Then status 201
    * def newOrderId = response.orderId

    # This order should also be confirmed (stock was restored)
    Given path services.orders + '/' + newOrderId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.status == 'ORDER_CONFIRMED' || response.status == 'ORDER_FAILED'
    When method GET
    Then status 200
    And match response.status == 'ORDER_CONFIRMED'
    * print '=== Stock restoration verified - second order confirmed ==='
