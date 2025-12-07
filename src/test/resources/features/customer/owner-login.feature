@auth @owner
Feature: Owner Login

  Background:
    * url baseUrls.customer
    * def signupPath = services.ownerSignup
    * def loginPath = services.ownerLogin

  @happy-path
  Scenario: [P1-AUTH-02] Owner login success
    # Setup: Create owner first
    * def email = generateOwnerEmail()
    * def username = generateUsername()

    Given path signupPath
    And request
      """
      {
        "username": "#(username)",
        "email": "#(email)",
        "password": "#(testPassword)",
        "phoneNumber": "010-1234-5678"
      }
      """
    When method POST
    Then status 201

    # Login
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
    And match response.accessToken == '#string'
    And match response.refreshToken == '#string'
    And match response.expiresIn == '#number'
    And match response.tokenType == 'Bearer'

  @error-case
  Scenario: Owner login with wrong password fails
    # Setup: Create owner first
    * def email = generateOwnerEmail()
    * def username = generateUsername()

    Given path signupPath
    And request
      """
      {
        "username": "#(username)",
        "email": "#(email)",
        "password": "#(testPassword)",
        "phoneNumber": "010-1234-5678"
      }
      """
    When method POST
    Then status 201

    # Login with wrong password
    Given path loginPath
    And request
      """
      {
        "email": "#(email)",
        "password": "WrongPassword123!"
      }
      """
    When method POST
    Then status 401
