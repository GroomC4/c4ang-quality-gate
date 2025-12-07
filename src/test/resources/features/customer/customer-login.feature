@auth @customer
Feature: Customer Login

  Background:
    * url baseUrls.customer
    * def signupPath = services.customerSignup
    * def loginPath = services.customerLogin

  @happy-path
  Scenario: [P1-CUST-01] Customer login success
    # Setup: Create customer first
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

  @error-case
  Scenario: [P1-CUST-04] Customer login with wrong password fails
    # Setup: Create customer first
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
