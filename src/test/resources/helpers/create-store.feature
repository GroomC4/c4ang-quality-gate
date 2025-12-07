@ignore
Feature: Create Store Helper

  Scenario: Create store with owner token
    * url baseUrl
    * def token = __arg.token
    * def storeName = __arg.name || 'Test Store ' + uuid().substring(0, 8)
    * def storeDescription = __arg.description || 'Test store description'

    Given path services.stores
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "name": "#(storeName)",
        "description": "#(storeDescription)"
      }
      """
    When method POST
    Then status 201
    * def storeId = response.storeId
    * def store = response
