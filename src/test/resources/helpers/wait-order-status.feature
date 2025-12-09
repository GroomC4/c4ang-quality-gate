@ignore
Feature: Wait for Order Status Helper

  Scenario: Poll order status until expected status or timeout
    * url baseUrls.order
    * def orderId = __arg.orderId
    * def expectedStatus = __arg.expectedStatus
    * def maxWait = __arg.maxWait || 15000
    * def interval = __arg.interval || 1000
    * def token = __arg.token
    * def userId = __arg.userId

    * def pollStatus =
      """
      function() {
        var maxRetries = Math.floor(maxWait / interval);
        for (var i = 0; i < maxRetries; i++) {
          var config = { orderId: orderId, token: token, userId: userId };
          var res = karate.call('classpath:helpers/get-order.feature', config);
          karate.log('Attempt', i + 1, '- Order Status:', res.order.status);

          if (res.order.status == expectedStatus) {
            return { success: true, order: res.order, attempts: i + 1 };
          }
          if (res.order.status.indexOf('FAILED') >= 0 || res.order.status.indexOf('CANCELLED') >= 0) {
            return { success: false, reason: res.order.status, order: res.order };
          }
          karate.pause(interval);
        }
        return { success: false, reason: 'TIMEOUT', order: res.order };
      }
      """

    * def result = pollStatus()
