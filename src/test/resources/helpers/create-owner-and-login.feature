@ignore
Feature: Create Owner and Login Helper

  Scenario: Create owner and get access token
    * url baseUrls.customer
    * def email = __arg.email || generateOwnerEmail()
    * def username = __arg.username || generateUsername()
    * def password = __arg.password || testPassword

    # Signup
    Given path services.ownerSignup
    And request
      """
      {
        "username": "#(username)",
        "email": "#(email)",
        "password": "#(password)",
        "phoneNumber": "010-1234-5678"
      }
      """
    When method POST
    Then status 201
    * def userId = response.user.id

    # Login
    Given path services.ownerLogin
    And request
      """
      {
        "email": "#(email)",
        "password": "#(password)"
      }
      """
    When method POST
    Then status 200
    * def accessToken = response.accessToken
    * def refreshToken = response.refreshToken
