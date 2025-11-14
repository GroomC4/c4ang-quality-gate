Feature: 고객 서비스 - 고객 생성

  Background:
    * url baseUrl
    * def customerEndpoint = services.customer
    # JWT 토큰 획득
    * def loginResponse = call read('classpath:features/auth/login.feature') { username: '#(testUser.username)', password: '#(testUser.password)' }
    * def authToken = loginResponse.token
    * header Authorization = 'Bearer ' + authToken

  Scenario: 새 고객 생성 성공
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "홍길동",
        "email": "hong.gildong@example.com",
        "phoneNumber": "010-1234-5678",
        "address": {
          "street": "테헤란로 123",
          "city": "서울",
          "zipCode": "06234"
        }
      }
      """
    When method POST
    Then status 201
    And match response.id == '#string'
    And match response.name == '홍길동'
    And match response.email == 'hong.gildong@example.com'
    And match response.phoneNumber == '010-1234-5678'
    And match response.address.city == '서울'
    And match response.createdAt == '#string'
    # 생성된 고객 ID 저장
    * def customerId = response.id

  Scenario: 중복된 이메일로 고객 생성 실패
    # 먼저 고객 생성
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "김철수",
        "email": "duplicate@example.com",
        "phoneNumber": "010-9999-8888"
      }
      """
    When method POST
    Then status 201
    * def firstCustomerId = response.id

    # 같은 이메일로 다시 생성 시도
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "이영희",
        "email": "duplicate@example.com",
        "phoneNumber": "010-7777-6666"
      }
      """
    When method POST
    Then status 409
    And match response.message contains '이메일'

  Scenario: 필수 필드 누락 시 고객 생성 실패
    Given path '/api/v1/customers'
    And request
      """
      {
        "email": "test@example.com"
      }
      """
    When method POST
    Then status 400
    And match response.message == '#string'

  Scenario: 유효하지 않은 이메일 형식으로 고객 생성 실패
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "박민수",
        "email": "invalid-email-format",
        "phoneNumber": "010-5555-4444"
      }
      """
    When method POST
    Then status 400
    And match response.message contains '이메일'
