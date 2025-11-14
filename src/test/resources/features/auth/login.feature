Feature: 인증 - 로그인 및 JWT 토큰 획득

  Background:
    * url baseUrl
    * def authEndpoint = services.auth + '/login'

  Scenario: 로그인 성공 및 JWT 토큰 획득
    Given path '/api/v1/auth/login'
    And request
      """
      {
        "username": "#(username)",
        "password": "#(password)"
      }
      """
    When method POST
    Then status 200
    And match response.token == '#string'
    And match response.token == '#notnull'
    * def token = response.token

  Scenario: 유효하지 않은 자격증명으로 로그인 실패
    Given path '/api/v1/auth/login'
    And request
      """
      {
        "username": "invalid@c4ang.com",
        "password": "wrongpassword"
      }
      """
    When method POST
    Then status 401
    And match response.message == '#string'

  Scenario: 필수 필드 누락 시 로그인 실패
    Given path '/api/v1/auth/login'
    And request
      """
      {
        "username": "test@c4ang.com"
      }
      """
    When method POST
    Then status 400
    And match response.message == '#string'
