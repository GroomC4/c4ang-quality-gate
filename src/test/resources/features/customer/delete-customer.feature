Feature: 고객 서비스 - 고객 삭제

  Background:
    * url baseUrl
    * def customerEndpoint = services.customer
    # JWT 토큰 획득
    * def loginResponse = call read('classpath:features/auth/login.feature') { username: '#(testUser.username)', password: '#(testUser.password)' }
    * def authToken = loginResponse.token
    * header Authorization = 'Bearer ' + authToken

  Scenario: 고객 삭제 성공
    # 먼저 고객 생성
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "삭제테스트",
        "email": "delete@example.com",
        "phoneNumber": "010-0000-1111"
      }
      """
    When method POST
    Then status 201
    * def customerId = response.id

    # 생성된 고객 삭제
    Given path '/api/v1/customers/' + customerId
    When method DELETE
    Then status 204

    # 삭제 확인 - 조회 시 404 응답
    Given path '/api/v1/customers/' + customerId
    When method GET
    Then status 404

  Scenario: 존재하지 않는 고객 삭제 실패
    Given path '/api/v1/customers/non-existent-id'
    When method DELETE
    Then status 404
    And match response.message == '#string'

  Scenario: 이미 삭제된 고객 재삭제 실패
    # 먼저 고객 생성
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "재삭제테스트",
        "email": "redelete@example.com",
        "phoneNumber": "010-2222-3333"
      }
      """
    When method POST
    Then status 201
    * def customerId = response.id

    # 첫 번째 삭제
    Given path '/api/v1/customers/' + customerId
    When method DELETE
    Then status 204

    # 두 번째 삭제 시도
    Given path '/api/v1/customers/' + customerId
    When method DELETE
    Then status 404
