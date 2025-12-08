@ignore
Feature: Create Store Helper

  Scenario: Create store with owner token
    * def args = __arg || {}
    * def token = args.token
    * def userId = args.userId
    * print 'DEBUG: token =', token
    * print 'DEBUG: userId =', userId
    * print 'DEBUG: userId type =', typeof userId
    * def storeName = args.name || 'Test Store ' + uuid().substring(0, 8)
    * def storeDescription = args.description || 'Test store description'

    # Request logging 활성화
    * configure logPrettyRequest = true
    * configure logPrettyResponse = true

    # 명시적으로 헤더 설정
    * def requestHeaders = { 'Authorization': '#("Bearer " + token)', 'X-User-Id': '#(userId)' }
    * print 'DEBUG: requestHeaders =', requestHeaders

    Given url baseUrls.store
    And path services.stores
    And headers requestHeaders
    And request
      """
      {
        "name": "#(storeName)",
        "description": "#(storeDescription)"
      }
      """
    When method POST
    * print 'DEBUG: response status =', responseStatus
    * print 'DEBUG: response =', response
    Then status 201
    * def storeId = response.storeId
    * def store = response
