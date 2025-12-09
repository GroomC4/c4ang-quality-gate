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
    # local 환경에서 Istio Gateway 없이 직접 호출 시 X-User-Id 헤더 필요
    * if (env == 'local' && userId) karate.set('requestHeaders', { 'X-User-Id': userId })
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
