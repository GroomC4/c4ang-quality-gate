@store
Feature: Store Update

  Background:
    * url baseUrl
    * def storePath = services.stores

  @happy-path
  Scenario: [P1-STORE-02] Owner updates store info
    # Setup: Create owner and store
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken

    Given path storePath
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "name": "Original Store Name",
        "description": "Original description"
      }
      """
    When method POST
    Then status 201
    * def storeId = response.storeId

    # Update store
    Given path storePath + '/' + storeId
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "name": "Updated Store Name",
        "description": "Updated description"
      }
      """
    When method PATCH
    Then status 200
    And match response.storeId == storeId
    And match response.name == 'Updated Store Name'
    And match response.description == 'Updated description'
    And match response.updatedAt == '#notnull'

  @error-case
  Scenario: [P1-STORE-04] Other owner cannot update store (403)
    # Setup: Create first owner and store
    * def owner1 = call read('classpath:helpers/create-owner-and-login.feature')
    * def token1 = owner1.accessToken

    Given path storePath
    And header Authorization = 'Bearer ' + token1
    And request
      """
      {
        "name": "Owner1 Store",
        "description": "Owner1's store"
      }
      """
    When method POST
    Then status 201
    * def storeId = response.storeId

    # Setup: Create second owner
    * def owner2 = call read('classpath:helpers/create-owner-and-login.feature')
    * def token2 = owner2.accessToken

    # Try to update with different owner
    Given path storePath + '/' + storeId
    And header Authorization = 'Bearer ' + token2
    And request
      """
      {
        "name": "Hijacked Store",
        "description": "Should fail"
      }
      """
    When method PATCH
    Then status 403
