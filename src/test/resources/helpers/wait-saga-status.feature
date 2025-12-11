@ignore
Feature: Wait for Saga Status Helper
  Saga Tracker API를 통해 비동기 이벤트 처리 완료를 검증

  Scenario: Poll saga status until expected status or timeout
    * url baseUrl
    * def orderId = __arg.orderId
    * def expectedStatus = __arg.expectedStatus
    * def maxWait = __arg.maxWait || 90000
    * def interval = __arg.interval || 3000
    * def token = __arg.token

    * def pollSagaStatus =
      """
      function() {
        var maxRetries = Math.floor(maxWait / interval);
        var sagaResult = null;

        for (var i = 0; i < maxRetries; i++) {
          karate.log('Saga Tracker polling attempt', i + 1, '/', maxRetries, 'for orderId:', orderId);

          // Saga Tracker API 호출 - orderId로 saga 조회
          var http = karate.http(baseUrl);
          http.path('/api/v1/sagas');
          http.param('orderId', orderId);
          http.header('Content-Type', 'application/json');
          http.header('Accept', 'application/json');
          if (token) {
            http.header('Authorization', 'Bearer ' + token);
          }

          var response = http.get();

          karate.log('Saga Tracker response status:', response.status);

          if (response.status == 200) {
            var body = response.body;
            karate.log('Saga Tracker response body:', JSON.stringify(body));

            // 응답이 배열인 경우 (목록 조회)
            var sagas = body.content || body;
            if (sagas && sagas.length > 0) {
              sagaResult = sagas[0];
              karate.log('Found saga:', sagaResult.sagaId, 'status:', sagaResult.status);

              if (sagaResult.status == expectedStatus) {
                return {
                  success: true,
                  saga: sagaResult,
                  attempts: i + 1,
                  message: 'Saga reached expected status: ' + expectedStatus
                };
              }

              // 실패/보상 완료 상태 체크
              if (expectedStatus != 'COMPENSATED' && expectedStatus != 'FAILED') {
                if (sagaResult.status == 'COMPENSATED' || sagaResult.status == 'FAILED') {
                  return {
                    success: false,
                    reason: sagaResult.status,
                    saga: sagaResult,
                    message: 'Saga ended in unexpected status: ' + sagaResult.status
                  };
                }
              }
            } else {
              karate.log('No saga found yet for orderId:', orderId);
            }
          } else if (response.status == 404) {
            karate.log('Saga not found yet for orderId:', orderId);
          } else {
            karate.log('Saga Tracker API error:', response.status, response.body);
          }

          karate.pause(interval);
        }

        return {
          success: false,
          reason: 'TIMEOUT',
          saga: sagaResult,
          message: 'Timeout waiting for saga status: ' + expectedStatus + ' (waited ' + maxWait + 'ms)'
        };
      }
      """

    * def result = pollSagaStatus()
