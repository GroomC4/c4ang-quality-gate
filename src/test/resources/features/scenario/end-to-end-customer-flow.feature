Feature: E2E 시나리오 - 고객 생애주기 전체 플로우

  Background:
    * url baseUrl
    # JWT 토큰 획득
    * def loginResponse = call read('classpath:features/auth/login.feature') { username: '#(testUser.username)', password: '#(testUser.password)' }
    * def authToken = loginResponse.token
    * header Authorization = 'Bearer ' + authToken

  Scenario: 완전한 고객 생애주기 테스트 - 생성, 조회, 수정, 삭제
    # Step 1: 로그인 확인
    * print '=== Step 1: 로그인 완료 ==='
    * assert authToken != null

    # Step 2: 새 고객 생성
    * print '=== Step 2: 새 고객 생성 ==='
    Given path '/api/v1/customers'
    And request
      """
      {
        "name": "E2E테스트고객",
        "email": "e2e.test@example.com",
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
    And match response.name == 'E2E테스트고객'
    * def customerId = response.id
    * print 'Created customer ID:', customerId

    # Step 3: 생성된 고객 조회
    * print '=== Step 3: 생성된 고객 조회 ==='
    Given path '/api/v1/customers/' + customerId
    When method GET
    Then status 200
    And match response.id == customerId
    And match response.name == 'E2E테스트고객'
    And match response.email == 'e2e.test@example.com'
    And match response.phoneNumber == '010-1234-5678'

    # Step 4: 고객 정보 수정
    * print '=== Step 4: 고객 정보 수정 ==='
    Given path '/api/v1/customers/' + customerId
    And request
      """
      {
        "phoneNumber": "010-9999-8888",
        "address": {
          "street": "강남대로 456",
          "city": "서울",
          "zipCode": "06789"
        }
      }
      """
    When method PATCH
    Then status 200
    And match response.id == customerId
    And match response.phoneNumber == '010-9999-8888'
    And match response.address.street == '강남대로 456'

    # Step 5: 수정된 정보 재조회 확인
    * print '=== Step 5: 수정된 정보 재조회 ==='
    Given path '/api/v1/customers/' + customerId
    When method GET
    Then status 200
    And match response.phoneNumber == '010-9999-8888'
    And match response.address.street == '강남대로 456'

    # Step 6: 고객 삭제
    * print '=== Step 6: 고객 삭제 ==='
    Given path '/api/v1/customers/' + customerId
    When method DELETE
    Then status 204

    # Step 7: 삭제 확인 - 조회 시 404
    * print '=== Step 7: 삭제 확인 ==='
    Given path '/api/v1/customers/' + customerId
    When method GET
    Then status 404

    * print '=== E2E 테스트 완료 ==='
