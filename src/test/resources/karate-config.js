function fn() {
  var env = karate.env;
  karate.log('karate.env system property was:', env);

  if (!env) {
    env = 'dev';
  }

  var config = {
    env: env,
    apiTimeout: 30000,
    retryInterval: 1000,
    maxRetries: 15,
    namespace: 'ecommerce'
  };

  // Environment-specific configuration
  if (env === 'dev') {
    // 개발/CI 환경 (k3d) - Istio Gateway를 통해 접근 (운영과 동일)
    // port-forward로 istio-ingressgateway에 연결 (localhost:8080 -> istio-ingressgateway:80)
    config.baseUrl = 'http://localhost:8080';
    // Istio Gateway 라우팅을 위한 Host 헤더 (Gateway hostname과 일치해야 함)
    // k3d 환경에서는 localhost 리스너 사용 (http-localhost)
    config.gatewayHost = 'localhost';
    // K3d 환경에서는 시작이 느릴 수 있으므로 재시도 횟수 증가
    config.maxRetries = 20;
    config.retryInterval = 2000;
  } else if (env === 'local') {
    // 로컬 테스트 환경 (k3d) - Istio 없이 개별 서비스에 port-forward로 접근
    // 각 서비스별로 다른 포트 사용:
    // customer-api: 8081, order-api: 8082, payment-api: 8083
    // product-api: 8084, store-api: 8085, saga-tracker-api: 8086
    config.baseUrl = 'http://localhost:8081'; // default for customer-api
    config.customerUrl = 'http://localhost:8081';
    config.orderUrl = 'http://localhost:8082';
    config.paymentUrl = 'http://localhost:8083';
    config.productUrl = 'http://localhost:8084';
    config.storeUrl = 'http://localhost:8085';
    config.sagaUrl = 'http://localhost:8086';
    config.maxRetries = 20;
    config.retryInterval = 2000;
  } else if (env === 'prod') {
    // 프로덕션 환경 (EKS) - Istio Gateway (ALB/NLB)를 통해 접근
    config.baseUrl = karate.properties['base.url'] || 'https://api.ecommerce.com';
  }

  // Common headers
  config.headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  };

  // dev 환경에서는 Istio Gateway 라우팅을 위해 Host 헤더 추가
  // (prod 환경에서는 DNS가 올바르게 설정되어 있으므로 Host 헤더 불필요)
  if (config.gatewayHost) {
    config.headers['Host'] = config.gatewayHost;
  }

  // Service endpoints - 모든 환경에서 Istio Gateway를 통해 접근
  config.services = {
    // Auth endpoints (customer-api)
    customerSignup: '/api/v1/auth/customers/signup',
    customerLogin: '/api/v1/auth/customers/login',
    customerLogout: '/api/v1/auth/customers/logout',
    ownerSignup: '/api/v1/auth/owners/signup',
    ownerLogin: '/api/v1/auth/owners/login',
    ownerLogout: '/api/v1/auth/owners/logout',
    tokenRefresh: '/api/v1/auth/refresh',

    // Store endpoints (store-api)
    stores: '/api/v1/stores',

    // Product endpoints (product-api)
    products: '/api/v1/products',

    // Order endpoints (order-api)
    orders: '/api/v1/orders',

    // Payment endpoints (payment-api)
    payments: '/api/v1/payments'
  };

  // 환경별 baseUrls 설정
  if (env === 'local') {
    // local 환경: 각 서비스별 개별 포트로 접근
    config.baseUrls = {
      customer: config.customerUrl,
      store: config.storeUrl,
      product: config.productUrl,
      order: config.orderUrl,
      payment: config.paymentUrl,
      saga: config.sagaUrl
    };
  } else {
    // dev/prod 환경: Gateway를 통해 동일 URL로 접근
    config.baseUrls = {
      customer: config.baseUrl,
      store: config.baseUrl,
      product: config.baseUrl,
      order: config.baseUrl,
      payment: config.baseUrl,
      saga: config.baseUrl
    };
  }

  // Retry configuration for async operations
  karate.configure('retry', { count: config.maxRetries, interval: config.retryInterval });
  karate.configure('connectTimeout', config.apiTimeout);
  karate.configure('readTimeout', config.apiTimeout);

  // Apply default headers to all requests (including Host header for Gateway routing)
  karate.configure('headers', config.headers);

  // UUID generator helper
  config.uuid = function() {
    return java.util.UUID.randomUUID().toString();
  };

  // Timestamp helper
  config.timestamp = function() {
    return new Date().getTime();
  };

  // Test data generators - self-contained functions (no config dependency)
  config.generateCustomerEmail = function() {
    var id = java.util.UUID.randomUUID().toString().substring(0, 8);
    return 'customer-' + id + '@test.c4ang.com';
  };

  config.generateOwnerEmail = function() {
    var id = java.util.UUID.randomUUID().toString().substring(0, 8);
    return 'owner-' + id + '@test.c4ang.com';
  };

  config.generateUsername = function() {
    var id = java.util.UUID.randomUUID().toString().substring(0, 8);
    return 'u' + id;
  };

  // Default test password
  config.testPassword = 'Test1234';

  // JWT payload에서 userId 추출 (local 환경에서 X-User-Id 헤더 생성용)
  config.parseJwtUserId = function(token) {
    if (!token) return null;
    try {
      var parts = token.split('.');
      if (parts.length !== 3) return null;
      var payload = parts[1];
      // Base64 URL decode
      var decoded = new java.lang.String(java.util.Base64.getUrlDecoder().decode(payload));
      var json = JSON.parse(decoded);
      return json.sub || json.userId || json.user_id || null;
    } catch (e) {
      karate.log('JWT parsing failed:', e);
      return null;
    }
  };

  // local 환경에서 인증된 요청에 X-User-Id 헤더를 자동 추가하는 helper
  // env 변수를 클로저로 캡처
  var currentEnv = env;
  config.setAuthHeaders = function(token, userId) {
    var headers = { 'Authorization': 'Bearer ' + token };
    // local 환경에서 X-User-Id 헤더 추가 (Istio Gateway 역할 대체)
    if (currentEnv === 'local' && userId) {
      headers['X-User-Id'] = String(userId);
    }
    return headers;
  };

  return config;
}
