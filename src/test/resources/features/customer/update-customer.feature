Feature: 고객 서비스 - 고객 정보 수정

  Background:
    * url baseUrl
    * def customerEndpoint = services.customer
    # JWT 토큰 획득
    * def loginResponse = call read('classpath:features/auth/login.feature') { username: '#(testUser.username)', password: '#(testUser.password)' }
    * def authToken = loginResponse.token
    * header Authorization = 'Bearer ' + authToken

  Scenario: 고객 정보 전체 수정 성공 (PUT)
    # 먼저 고객 생성
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "수정전이름",
        "email": "before@example.com",
        "phoneNumber": "010-0000-0000"
      }
      """
    When method POST
    Then status 201
    * def customerId = response.id

    # 고객 정보 전체 수정
    Given path '/api/v1/customers/' + customerId
    And request
      """
      {
        "name": "수정후이름",
        "email": "after@example.com",
        "phoneNumber": "010-9999-9999",
        "address": {
          "street": "강남대로 456",
          "city": "서울",
          "zipCode": "06789"
        }
      }
      """
    When method PUT
    Then status 200
    And match response.id == customerId
    And match response.name == '수정후이름'
    And match response.email == 'after@example.com'
    And match response.phoneNumber == '010-9999-9999'
    And match response.address.street == '강남대로 456'

  Scenario: 고객 정보 부분 수정 성공 (PATCH)
    # 먼저 고객 생성
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "원본이름",
        "email": "original@example.com",
        "phoneNumber": "010-1234-5678"
      }
      """
    When method POST
    Then status 201
    * def customerId = response.id

    # 전화번호만 부분 수정
    Given path '/api/v1/customers/' + customerId
    And request
      """
      {
        "phoneNumber": "010-8888-7777"
      }
      """
    When method PATCH
    Then status 200
    And match response.id == customerId
    And match response.name == '원본이름'
    And match response.email == 'original@example.com'
    And match response.phoneNumber == '010-8888-7777'

  Scenario: 존재하지 않는 고객 수정 실패
    Given path '/api/v1/customers/non-existent-id'
    And request
      """
      {
        "name": "실패테스트",
        "email": "fail@example.com"
      }
      """
    When method PUT
    Then status 404
    And match response.message == '#string'
