@ignore
Feature: Create Customer and Login Helper

  Scenario: Create customer and get access token
    * url baseUrl
    * def email = __arg.email || generateCustomerEmail()
    * def username = __arg.username || generateUsername()
    * def password = __arg.password || testPassword

    # Signup
    Given path services.customerSignup
    And request
      """
      {
        "username": "#(username)",
        "email": "#(email)",
        "password": "#(password)",
        "defaultAddress": "서울특별시 강남구 테헤란로 123",
        "defaultPhoneNumber": "010-1234-5678"
      }
      """
    When method POST
    Then status 201
    * def userId = response.userId

    # Login
    Given path services.customerLogin
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
