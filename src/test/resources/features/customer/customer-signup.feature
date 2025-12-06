@auth @customer
Feature: Customer Signup

  Background:
    * url baseUrl
    * def signupPath = services.customerSignup

  @happy-path
  Scenario: [P1-AUTH-01] Customer signup success
    * def email = generateCustomerEmail()
    * def username = generateUsername()

    Given path signupPath
    And request
      """
      {
        "username": "#(username)",
        "email": "#(email)",
        "password": "#(testPassword)",
        "defaultPhoneNumber": "010-1234-5678"
      }
      """
    When method POST
    Then status 201
    And match response.userId == '#uuid'
    And match response.username == username
    And match response.email == email
    And match response.role == 'CUSTOMER'
    And match response.isActive == true
    And match response.createdAt == '#notnull'

  @error-case
  Scenario: [P1-AUTH-04] Customer signup with duplicate email fails
    * def email = generateCustomerEmail()
    * def username1 = generateUsername()
    * def username2 = generateUsername()

    # First signup
    Given path signupPath
    And request
      """
      {
        "username": "#(username1)",
        "email": "#(email)",
        "password": "#(testPassword)"
      }
      """
    When method POST
    Then status 201

    # Second signup with same email
    Given path signupPath
    And request
      """
      {
        "username": "#(username2)",
        "email": "#(email)",
        "password": "#(testPassword)"
      }
      """
    When method POST
    Then status 409

  @error-case
  Scenario: Customer signup with invalid email format fails
    Given path signupPath
    And request
      """
      {
        "username": "#(generateUsername())",
        "email": "invalid-email",
        "password": "#(testPassword)"
      }
      """
    When method POST
    Then status 400
