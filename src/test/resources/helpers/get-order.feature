@ignore
Feature: Get Order Helper

  Scenario: Get order by ID
    * url baseUrls.order
    * def orderId = __arg.orderId
    * def token = __arg.token
    * def userId = __arg.userId

    Given path services.orders + '/' + orderId
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    When method GET
    Then status 200
    * def order = response
