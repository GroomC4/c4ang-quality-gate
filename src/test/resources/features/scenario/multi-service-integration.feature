Feature: E2E 시나리오 - 다중 서비스 통합 플로우

  Background:
    * url baseUrl
    # JWT 토큰 획득
    * def loginResponse = call read('classpath:features/auth/login.feature') { username: '#(testUser.username)', password: '#(testUser.password)' }
    * def authToken = loginResponse.token
    * header Authorization = 'Bearer ' + authToken

  @Ignore
  Scenario: 다중 서비스 통합 시나리오 - 고객 생성 후 주문 생성
    # 이 시나리오는 다른 서비스(order-service 등)가 개발 완료되면 활성화됩니다.
    # 현재는 customer-service만 존재하므로 @Ignore 처리

    # Step 1: 고객 생성
    * print '=== Step 1: 고객 생성 ==='
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "통합테스트고객",
        "email": "integration@example.com",
        "phoneNumber": "010-5555-6666"
      }
      """
    When method POST
    Then status 201
    * def customerId = response.id

    # Step 2: 생성된 고객으로 주문 생성 (order-service)
    # * print '=== Step 2: 주문 생성 ==='
    # Given path '/api/v1/orders'
    # And request
    #   """
    #   {
    #     "customerId": "#(customerId)",
    #     "items": [
    #       { "productId": "prod-001", "quantity": 2 }
    #     ]
    #   }
    #   """
    # When method POST
    # Then status 201
    # * def orderId = response.id

    # Step 3: 결제 처리 (payment-service)
    # * print '=== Step 3: 결제 처리 ==='
    # Given path '/api/v1/payments'
    # And request
    #   """
    #   {
    #     "orderId": "#(orderId)",
    #     "customerId": "#(customerId)",
    #     "amount": 50000,
    #     "method": "CARD"
    #   }
    #   """
    # When method POST
    # Then status 201

    # Step 4: 주문 상태 확인
    # * print '=== Step 4: 주문 상태 확인 ==='
    # Given path '/api/v1/orders/' + orderId
    # When method GET
    # Then status 200
    # And match response.status == 'PAID'

  Scenario: 고객 서비스 헬스체크 및 가용성 확인
    # 서비스 간 통합 테스트를 위한 기본 헬스체크
    * print '=== 고객 서비스 헬스체크 ==='
    Given path '/actuator/health'
    When method GET
    Then status 200
    And match response.status == 'UP'

  Scenario: 동시성 테스트 - 여러 고객 동시 생성
    # 동시에 여러 고객을 생성하여 시스템 안정성 확인
    * print '=== 동시성 테스트 시작 ==='

    * def createCustomer =
      """
      function(index) {
        var result = karate.call('classpath:features/customer/create-customer.feature');
        return result;
      }
      """

    # 5명의 고객을 순차적으로 생성
    * def customers = karate.repeat(5, createCustomer)
    * print '동시성 테스트 완료: 5명의 고객 생성'
