@order
Feature: Order Query

  Background:
    * url baseUrls.order
    * def orderPath = services.orders

  @happy-path
  Scenario: Get order by ID
    # Setup: Create owner with store and product
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def ownerToken = owner.accessToken
    * def ownerId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(ownerToken)', userId: '#(ownerId)' }
    * def storeId = store.storeId
    * def product = call read('classpath:helpers/create-product.feature') { token: '#(ownerToken)', userId: '#(ownerId)', storeId: '#(storeId)' }
    * def productId = product.productId

    # Create customer and order
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId

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
            "quantity": 1,
            "unitPrice": 10000
          }
        ]
      }
      """
    When method POST
    Then status 201
    * def orderId = response.orderId

    # Get order by ID
    Given path orderPath + '/' + orderId
    And header Authorization = 'Bearer ' + customerToken
    And header X-User-Id = customerId
    When method GET
    Then status 200
    And match response.orderId == orderId
    And match response.items == '#array'
    And match response.totalAmount == '#number'

  @happy-path
  Scenario: List customer's orders
    # Setup: Create owner with store and product
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def ownerToken = owner.accessToken
    * def ownerId = owner.userId
    * def store = call read('classpath:helpers/create-store.feature') { token: '#(ownerToken)', userId: '#(ownerId)' }
    * def storeId = store.storeId
    * def product = call read('classpath:helpers/create-product.feature') { token: '#(ownerToken)', userId: '#(ownerId)', storeId: '#(storeId)' }
    * def productId = product.productId

    # Create customer
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId

    # Create multiple orders
    Given path orderPath
    And header Authorization = 'Bearer ' + customerToken
    And header X-User-Id = customerId
    And request
      """
      {
        "storeId": "#(storeId)",
        "idempotencyKey": "#(uuid())",
        "items": [{ "productId": "#(productId)", "productName": "Product 1", "quantity": 1, "unitPrice": 5000 }]
      }
      """
    When method POST
    Then status 201

    Given path orderPath
    And header Authorization = 'Bearer ' + customerToken
    And header X-User-Id = customerId
    And request
      """
      {
        "storeId": "#(storeId)",
        "idempotencyKey": "#(uuid())",
        "items": [{ "productId": "#(productId)", "productName": "Product 2", "quantity": 2, "unitPrice": 7000 }]
      }
      """
    When method POST
    Then status 201

    # List orders
    Given path orderPath
    And header Authorization = 'Bearer ' + customerToken
    And header X-User-Id = customerId
    When method GET
    Then status 200
    And match response.orders == '#array'
    And match response.orders == '#[_ >= 2]'

  @error-case
  Scenario: Get non-existent order returns 404
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId
    * def fakeOrderId = uuid()

    Given path orderPath + '/' + fakeOrderId
    And header Authorization = 'Bearer ' + customerToken
    And header X-User-Id = customerId
    When method GET
    Then status 404
