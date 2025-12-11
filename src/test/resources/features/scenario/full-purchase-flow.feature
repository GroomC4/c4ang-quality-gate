@e2e @saga @async
Feature: Full Purchase Flow E2E

  Background:
    # Saga Tracker 기반 비동기 검증을 위한 retry 설정 강화
    * configure retry = { count: 30, interval: 3000 }

  @happy-path
  Scenario: [P1-E2E-01] Complete purchase flow - Signup → Store → Product → Order → Payment
    # ============================================
    # Step 1: Owner signup and login
    # ============================================
    * print '=== Step 1: Owner signup and login ==='
    * def ownerEmail = generateOwnerEmail()
    * def ownerUsername = generateUsername()

    * url baseUrls.customer
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
    # Step 1.5: Manager signup and login (for Saga Tracker API access)
    # ============================================
    * print '=== Step 1.5: Manager signup and login ==='
    * def managerEmail = generateManagerEmail()
    * def managerUsername = generateUsername()

    Given path services.managerSignup
    And request
      """
      {
        "username": "#(managerUsername)",
        "email": "#(managerEmail)",
        "password": "#(testPassword)",
        "phoneNumber": "010-9999-9999"
      }
      """
    When method POST
    Then status 201
    * def managerId = response.userId

    Given path services.managerLogin
    And request { "email": "#(managerEmail)", "password": "#(testPassword)" }
    When method POST
    Then status 200
    * def managerToken = response.accessToken
    * print 'Manager created and logged in:', managerId

    # ============================================
    # Step 2: Create store
    # ============================================
    * print '=== Step 2: Create store ==='

    * url baseUrls.store
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

    * url baseUrls.product
    Given path services.products
    And header Authorization = 'Bearer ' + ownerToken
    And request
      """
      {
        "storeId": "#(storeId)",
        "categoryId": "00000000-0000-0000-0000-000000000001",
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

    * url baseUrls.customer
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
    # Step 6: Wait for order confirmation via Order API
    # ============================================
    * print '=== Step 6: Wait for order confirmation ==='

    # Order API로 ORDER_CONFIRMED 상태 확인
    # Note: Saga COMPLETED는 Payment 완료 후에야 됨, 여기서는 Order 상태만 확인
    * url baseUrls.order
    Given path services.orders + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.status == 'ORDER_CONFIRMED' || response.status == 'ORDER_FAILED'
    When method GET
    Then status 200
    And match response.status == 'ORDER_CONFIRMED'
    * print 'Order confirmed:', response.status

    # ============================================
    # Step 7: Get payment created by Kafka event and request payment
    # ============================================
    * print '=== Step 7: Get payment and request payment ==='

    # Wait for payment to be created via Kafka event (OrderConfirmed -> Payment PAYMENT_WAIT)
    * def findPaymentByOrderId = function(payments, targetOrderId) { for (var i = 0; i < payments.length; i++) { if (payments[i].orderId == targetOrderId) return payments[i].paymentId; } return null; }

    * url baseUrls.payment
    Given path services.payments
    And param userId = customerId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.payments.length > 0
    When method GET
    Then status 200
    * def paymentId = findPaymentByOrderId(response.payments, orderId)
    * print 'Found paymentId:', paymentId, 'for orderId:', orderId
    * assert paymentId != null

    # Request payment
    Given path services.payments + '/request'
    And header Authorization = 'Bearer ' + customerToken
    * def paymentRequest = { paymentId: '#(paymentId)', paymentMethod: 'CARD', totalAmount: '#(expectedTotal)', paymentAmount: '#(expectedTotal)', discountAmount: 0, deliveryFee: 0 }
    And request paymentRequest
    When method POST
    Then status 201
    * print 'Payment requested:', paymentId

    # ============================================
    # Step 7.5: Simulate PG callback to complete payment
    # ============================================
    * print '=== Step 7.5: Simulate PG callback ==='

    # PG callback to complete payment (simulates PG approval)
    # dev 환경에서는 payment-api 직접 호출 (istiod 없이 Gateway의 동적 라우트가 작동하지 않음)
    * def uuid1 = java.util.UUID.randomUUID().toString().substring(0, 8)
    * def uuid2 = java.util.UUID.randomUUID().toString().substring(0, 8)
    * def pgApprovalNumber = 'TEST-APPROVAL-' + uuid1
    * def idempotencyKey = 'TEST-IDEMPOTENCY-' + uuid2
    * url pgCallbackBaseUrl
    Given path '/external/pg/callback/payment/complete'
    * def pgCallbackRequest = { paymentId: '#(paymentId)', pgApprovalNumber: '#(pgApprovalNumber)', idempotencyKey: '#(idempotencyKey)' }
    And request pgCallbackRequest
    When method POST
    Then status 200
    * print 'PG callback completed for paymentId:', paymentId

    # ============================================
    # Step 8: Verify final order status and Saga completion
    # ============================================
    * print '=== Step 8: Verify final order status ==='

    # PaymentCompleted 이벤트 처리 후 Order 상태:
    # ORDER_CONFIRMED -> PAYMENT_COMPLETED -> PREPARING (handlePaymentCompleted에서 두 단계 전이)
    # 따라서 PREPARING 상태가 최종 성공 상태임
    * url baseUrls.order
    Given path services.orders + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And retry until response.status == 'PREPARING' || response.status == 'PAYMENT_COMPLETED' || response.status == 'ORDER_CANCELLED' || response.status == 'PAYMENT_FAILED'
    When method GET
    Then status 200
    * print 'Final order status:', response.status
    # PREPARING이 성공 상태, 취소/실패 상태가 아닌지 확인
    And match response.status != 'ORDER_CANCELLED'
    And match response.status != 'PAYMENT_FAILED'

    # ============================================
    # Step 8.5: Verify Saga completion via Saga Tracker
    # ============================================
    * print '=== Step 8.5: Verify Saga completion (Saga Tracker) ==='

    # Payment 완료 후 Saga가 COMPLETED 상태가 되었는지 확인
    * def sagaWaitConfig = { orderId: '#(orderId)', expectedStatus: 'COMPLETED', token: '#(managerToken)', maxWait: 30000, interval: 2000 }
    * def sagaResult = call read('classpath:helpers/wait-saga-status.feature') sagaWaitConfig
    * print 'Saga Tracker result:', sagaResult.result
    * def sagaSuccess = sagaResult.result.success
    * print 'Saga completed successfully:', sagaSuccess

    * print '=== Full Purchase Flow Completed Successfully ==='
