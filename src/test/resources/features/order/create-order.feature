@order @saga
Feature: Order Creation

  Background:
    * url baseUrls.order
    * def orderPath = services.orders

  @happy-path
  Scenario: [P1-ORDER-01] Customer creates order successfully
    # Setup: Create owner with store and product
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def ownerToken = owner.accessToken
    * def ownerId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(ownerToken)', userId: '#(ownerId)' }
    * def storeId = store.storeId
    * def product = call read('classpath:helpers/create-product.feature') { token: '#(ownerToken)', userId: '#(ownerId)', storeId: '#(storeId)', price: 10000, stockQuantity: 100 }
    * def productId = product.productId

    # Setup: Create customer
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId

    # Create order
    * def idempotencyKey = uuid()
    Given path orderPath
    And header Authorization = 'Bearer ' + customerToken
    And header X-User-Id = customerId
    And request
      """
      {
        "storeId": "#(storeId)",
        "idempotencyKey": "#(idempotencyKey)",
        "items": [
          {
            "productId": "#(productId)",
            "productName": "Test Product",
            "quantity": 2,
            "unitPrice": 10000
          }
        ],
        "note": "E2E test order"
      }
      """
    When method POST
    Then status 201
    And match response.orderId == '#uuid'
    And match response.orderNumber == '#string'
    And match response.status == '#string'
    And match response.totalAmount == 20000
    And match response.items == '#array'
    And match response.items[0].productId == productId
    And match response.items[0].quantity == 2
    And match response.createdAt == '#notnull'

  @happy-path @async
  Scenario: [P1-ORDER-02] Order confirmed after stock reservation
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
    And header X-User-Id = customerId
    And request
      """
      {
        "storeId": "#(storeId)",
        "idempotencyKey": "#(uuid())",
        "items": [
          {
            "productId": "#(productId)",
            "productName": "Test Product",
            "quantity": 5,
            "unitPrice": 10000
          }
        ]
      }
      """
    When method POST
    Then status 201
    * def orderId = response.orderId

    # Wait for order confirmation (async SAGA)
    Given path orderPath + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And header X-User-Id = customerId
    And retry until response.status == 'ORDER_CONFIRMED' || response.status == 'ORDER_FAILED'
    When method GET
    Then status 200
    And match response.status == 'ORDER_CONFIRMED'

  @error-case
  Scenario: Order creation without authentication fails
    Given path orderPath
    And request
      """
      {
        "storeId": "#(uuid())",
        "idempotencyKey": "#(uuid())",
        "items": [
          {
            "productId": "#(uuid())",
            "productName": "Test",
            "quantity": 1,
            "unitPrice": 1000
          }
        ]
      }
      """
    When method POST
    # 인증 없이 요청 시 400(Bad Request) 또는 401(Unauthorized) 모두 허용
    Then assert responseStatus == 400 || responseStatus == 401
