@store
Feature: Store Deletion

  Background:
    * url baseUrl
    * def storePath = services.stores

  @happy-path
  Scenario: [P1-STORE-03] Owner deletes store (soft delete)
    # Setup: Create owner and store
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken

    Given path storePath
    And header Authorization = 'Bearer ' + token
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
    When method DELETE
    Then status 200
    And match response.storeId == storeId
    And match response.deletedAt == '#notnull'

  @error-case
  Scenario: [P1-STORE-04] Other owner cannot delete store (403)
    # Setup: Create first owner and store
    * def owner1 = call read('classpath:helpers/create-owner-and-login.feature')
    * def token1 = owner1.accessToken

    Given path storePath
    And header Authorization = 'Bearer ' + token1
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

    # Try to delete with different owner
    Given path storePath + '/' + storeId
    And header Authorization = 'Bearer ' + token2
    When method DELETE
    Then status 403
