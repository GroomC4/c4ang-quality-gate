@auth @customer
Feature: Customer Login

  Background:
    * url baseUrl
    * def signupPath = services.customerSignup
    * def loginPath = services.customerLogin

  @happy-path
  Scenario: [P1-AUTH-01] Customer login success
    # Setup: Create customer first
    * def email = generateCustomerEmail()
    * def username = generateUsername()

    Given path signupPath
    And request
      """
      {
        "username": "#(username)",
        "email": "#(email)",
        "password": "#(testPassword)"
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
  Scenario: [P1-AUTH-04] Customer login with wrong password fails
    # Setup: Create customer first
    * def email = generateCustomerEmail()
    * def username = generateUsername()

    Given path signupPath
    And request
      """
      {
        "username": "#(username)",
        "email": "#(email)",
        "password": "#(testPassword)"
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

  @error-case
  Scenario: Customer login with non-existent email fails
    Given path loginPath
    And request
      """
      {
        "email": "nonexistent@test.c4ang.com",
        "password": "#(testPassword)"
      }
      """
    When method POST
    Then status 401
