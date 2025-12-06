@ignore
Feature: Get Order Helper

  Scenario: Get order by ID
    * url baseUrl
    * def orderId = __arg.orderId
    * def token = __arg.token

    Given path services.orders + '/' + orderId
    And header Authorization = 'Bearer ' + token
    When method GET
    Then status 200
    * def order = response
