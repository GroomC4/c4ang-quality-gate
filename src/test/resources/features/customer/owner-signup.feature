@auth @owner
Feature: Owner Signup

  Background:
    * url baseUrl
    * def signupPath = services.ownerSignup

  @happy-path
  Scenario: [P1-AUTH-02] Owner signup success
    * def email = generateOwnerEmail()
    * def username = generateUsername()

    Given path signupPath
    And request
      """
      {
        "username": "#(username)",
        "email": "#(email)",
        "password": "#(testPassword)",
        "phoneNumber": "010-9876-5432"
      }
      """
    When method POST
    Then status 201
    And match response.user.id == '#uuid'
    And match response.user.name == username
    And match response.user.email == email
    And match response.createdAt == '#notnull'

  @error-case
  Scenario: Owner signup with duplicate email fails
    * def email = generateOwnerEmail()
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
        "phoneNumber": "010-1111-2222"
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
        "phoneNumber": "010-3333-4444"
      }
      """
    When method POST
    Then status 409
