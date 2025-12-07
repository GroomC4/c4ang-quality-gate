@auth @customer
Feature: Customer Signup

  Background:
    * url baseUrls.customer
    * def signupPath = services.customerSignup

  @happy-path
  Scenario: [P1-CUST-01] Customer signup success
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
    And match response.userId == '#uuid'
    And match response.username == username
    And match response.email == email

  @error-case
  Scenario: [P1-CUST-04] Customer signup with duplicate email fails
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
        "password": "#(testPassword)",
        "defaultAddress": "서울특별시 강남구 테헤란로 123",
        "defaultPhoneNumber": "010-1234-5678"
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
        "password": "#(testPassword)",
        "defaultAddress": "서울특별시 서초구 반포대로 456",
        "defaultPhoneNumber": "010-9876-5432"
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
        "password": "#(testPassword)",
        "defaultAddress": "서울특별시 강남구 테헤란로 123",
        "defaultPhoneNumber": "010-1234-5678"
      }
      """
    When method POST
    Then status 400
