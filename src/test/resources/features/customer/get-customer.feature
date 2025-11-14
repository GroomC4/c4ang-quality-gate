Feature: 고객 서비스 - 고객 조회

  Background:
    * url baseUrl
    * def customerEndpoint = services.customer
    # JWT 토큰 획득
    * def loginResponse = call read('classpath:features/auth/login.feature') { username: '#(testUser.username)', password: '#(testUser.password)' }
    * def authToken = loginResponse.token
    * header Authorization = 'Bearer ' + authToken

  Scenario: 고객 ID로 조회 성공
    # 먼저 고객 생성
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "조회테스트",
        "email": "gettest@example.com",
        "phoneNumber": "010-1111-2222"
      }
      """
    When method POST
    Then status 201
    * def customerId = response.id

    # 생성된 고객 조회
    Given path '/api/v1/customers/' + customerId
    When method GET
    Then status 200
    And match response.id == customerId
    And match response.name == '조회테스트'
    And match response.email == 'gettest@example.com'

  Scenario: 존재하지 않는 고객 ID로 조회 실패
    Given path '/api/v1/customers/non-existent-id-12345'
    When method GET
    Then status 404
    And match response.message == '#string'

  Scenario: 모든 고객 목록 조회
    Given path '/api/v1/customers'
    When method GET
    Then status 200
    And match response == '#array'
    And match each response contains { id: '#string', name: '#string', email: '#string' }

  Scenario: 페이징 처리된 고객 목록 조회
    Given path '/api/v1/customers'
    And param page = 0
    And param size = 10
    And param sort = 'createdAt,desc'
    When method GET
    Then status 200
    And match response.content == '#array'
    And match response.totalElements == '#number'
    And match response.totalPages == '#number'
    And match response.size == 10
