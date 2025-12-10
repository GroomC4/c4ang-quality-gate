@payment
Feature: Payment Query

  Background:
    * url baseUrls.payment
    * def paymentPath = services.payments

  @happy-path
  Scenario: List payments by userId
    # This test lists payments for a new user (should be empty or have payments)
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId

    # List payments requires userId parameter
    Given path paymentPath
    And param userId = customerId
    And header Authorization = 'Bearer ' + customerToken
    And header X-User-Id = customerId
    When method GET
    Then status 200
    And match response.payments == '#array'

  @error-case
  Scenario: Get non-existent payment returns 400
    # payment-service throws IllegalArgumentException for not found payment
    # which is mapped to 400 Bad Request with INVALID_REQUEST_PARAMETER code
    * def customer = call read('classpath:helpers/create-customer-and-login.feature')
    * def customerToken = customer.accessToken
    * def customerId = customer.userId
    * def fakePaymentId = uuid()

    Given path paymentPath + '/' + fakePaymentId
    And header Authorization = 'Bearer ' + customerToken
    And header X-User-Id = customerId
    When method GET
    Then status 400
    And match response.code == 'INVALID_REQUEST_PARAMETER'
