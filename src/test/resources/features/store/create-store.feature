@store
Feature: Store Creation

  Background:
    * url baseUrls.store
    * def storePath = services.stores

  @happy-path
  Scenario: [P1-STORE-01] Owner creates store successfully
    # Setup: Create owner and login
    * def owner = call read('classpath:helpers/create-owner-and-login.feature')
    * def token = owner.accessToken

    Given path storePath
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "name": "Test Store",
        "description": "A test store for E2E testing"
      }
      """
    When method POST
    Then status 201
    And match response.storeId == '#uuid'
    And match response.name == 'Test Store'
    And match response.description == 'A test store for E2E testing'
    And match response.status == '#string'
    And match response.createdAt == '#notnull'

  @error-case
  Scenario: [P1-STORE-04] Customer cannot create store (403)
    # Setup: Create customer and login
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def token = customer.accessToken

    Given path storePath
    And header Authorization = 'Bearer ' + token
    And request
      """
      {
        "name": "Customer Store",
        "description": "Should fail"
      }
      """
    When method POST
    Then status 403

  @error-case
  Scenario: Store creation without authentication fails
    # Note: May return 400 (service X-User-Id missing), 401 (unauthenticated), or 403 (Istio AuthorizationPolicy)
    Given path storePath
    And request
      """
      {
        "name": "Unauthorized Store",
        "description": "Should fail"
      }
      """
    When method POST
    Then assert responseStatus == 400 || responseStatus == 401 || responseStatus == 403
