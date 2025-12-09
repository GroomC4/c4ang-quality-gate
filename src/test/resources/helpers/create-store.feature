@ignore
Feature: Create Store Helper

  Scenario: Create store with owner token
    * def args = __arg || {}
    * def token = args.token
    * def userId = args.userId
    * def storeName = args.name || 'Test Store ' + uuid().substring(0, 8)
    * def storeDescription = args.description || 'Test store description'

    Given url baseUrls.store
    And path services.stores
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
