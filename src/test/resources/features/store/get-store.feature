@store
Feature: Store Retrieval

  Background:
    * url baseUrls.store
    * def storePath = services.stores

  @happy-path
  Scenario: [P1-STORE-01] Get store by ID
    # Setup: Create owner and store
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken

    Given path storePath
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "name": "Test Store for Retrieval",
        "description": "Store description"
      }
      """
    When method POST
    Then status 201
    * def storeId = response.storeId

    # Get store
    Given path storePath + '/' + storeId
    And header Authorization = 'Bearer ' + token
    When method GET
    Then status 200
    And match response.storeId == storeId
    And match response.name == 'Test Store for Retrieval'
    And match response.description == 'Store description'

  @happy-path
  Scenario: Get my store
    # Setup: Create owner and store
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken

    Given path storePath
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "name": "My Store",
        "description": "Owner's store"
      }
      """
    When method POST
    Then status 201
    * def storeId = response.storeId

    # Get my store
    Given path storePath + '/mine'
    And header Authorization = 'Bearer ' + token
    When method GET
    Then status 200
    And match response.storeId == storeId
    And match response.name == 'My Store'

  @error-case
  Scenario: [P1-STORE-05] Get non-existent store returns 404
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken
    * def fakeStoreId = uuid()

    Given path storePath + '/' + fakeStoreId
    And header Authorization = 'Bearer ' + token
    When method GET
    Then status 404
