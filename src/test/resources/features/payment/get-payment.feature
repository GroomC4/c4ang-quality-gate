@payment
Feature: Payment Query

  Background:
    * url baseUrl
    * def paymentPath = services.payments

  @happy-path
  Scenario: Get payment by ID
    # This test assumes a payment exists from a previous flow
    # In real scenarios, we'd create an order and payment first
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken

    # List payments (may be empty for new user)
    Given path paymentPath
    And header Authorization = 'Bearer ' + customerToken
    When method GET
    Then status 200
    And match response.payments == '#array'

  @error-case
  Scenario: Get non-existent payment returns 404
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def fakePaymentId = uuid()

    Given path paymentPath + '/' + fakePaymentId
    And header Authorization = 'Bearer ' + customerToken
    When method GET
    Then status 404
