@ignore
Feature: Create Store Helper

  Scenario: Create store with owner token
    * url baseUrls.store
    * def token = __arg.token
    * def userId = __arg.userId
    * def storeName = __arg.name || 'Test Store ' + uuid().substring(0, 8)
    * def storeDescription = __arg.description || 'Test store description'

    Given path services.stores
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
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
