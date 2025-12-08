@store
Feature: Store Deletion

  Background:
    * url baseUrls.store
    * def storePath = services.stores

  @happy-path
  Scenario: [P1-STORE-03] Owner deletes store (soft delete)
    # Setup: Create owner and store
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken
    * def userId = owner.userId

    Given path storePath
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    And request
      """
      {
        "name": "Store to Delete",
        "description": "Will be deleted"
      }
      """
    When method POST
    Then status 201
    * def storeId = response.storeId

    # Delete store
    Given path storePath + '/' + storeId
    And header Authorization = 'Bearer ' + token
    And header X-User-Id = userId
    When method DELETE
    Then status 200
    And match response.storeId == storeId
    And match response.deletedAt == '#notnull'

  @error-case
  Scenario: [P1-STORE-04] Other owner cannot delete store (403)
    # Setup: Create first owner and store
    * def owner1 = call read('classpath:helpers/create-owner-and-login.feature')
    * def token1 = owner1.accessToken
    * def userId1 = owner1.userId

    Given path storePath
    And header Authorization = 'Bearer ' + token1
    And header X-User-Id = userId1
    And request
      """
      {
        "name": "Protected Store",
        "description": "Cannot be deleted by others"
      }
      """
    When method POST
    Then status 201
    * def storeId = response.storeId

    # Setup: Create second owner
    * def owner2 = call read('classpath:helpers/create-owner-and-login.feature')
    * def token2 = owner2.accessToken
    * def userId2 = owner2.userId

    # Try to delete with different owner
    Given path storePath + '/' + storeId
    And header Authorization = 'Bearer ' + token2
    And header X-User-Id = userId2
    When method DELETE
    Then status 403
