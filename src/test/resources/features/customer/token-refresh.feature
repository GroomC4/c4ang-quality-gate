@auth
Feature: Token Refresh

  Background:
    * url baseUrls.customer
    * def signupPath = services.customerSignup
    * def loginPath = services.customerLogin
    * def refreshPath = services.tokenRefresh

  @happy-path
  Scenario: [P1-AUTH-03] Token refresh success
    # Setup: Create and login customer
    * def email = generateCustomerEmail()
    * def username = generateUsername()

    Given path signupPath
    And request
      """
      {
        "username": "#(username)",
        "email": "#(email)",
        "password": "#(testPassword)",
        "defaultAddress": "서울특별시 강남구 테헤란로 123",
        "defaultPhoneNumber": "010-1234-5678"
      }
      """
    When method POST
    Then status 201

    Given path loginPath
    And request
      """
      {
        "email": "#(email)",
        "password": "#(testPassword)"
      }
      """
    When method POST
    Then status 200
    * def refreshToken = response.refreshToken

    # Refresh token
    Given path refreshPath
    And request
      """
      {
        "refreshToken": "#(refreshToken)"
      }
      """
    When method POST
    Then status 200
    And match response.accessToken == '#string'
    And match response.expiresIn == '#number'
    And match response.tokenType == 'Bearer'

  @error-case
  Scenario: [P1-AUTH-05] Token refresh with invalid token fails
    Given path refreshPath
    And request
      """
      {
        "refreshToken": "invalid-refresh-token"
      }
      """
    When method POST
    Then status 401
