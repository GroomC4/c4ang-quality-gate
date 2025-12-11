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
    // 개발/CI 환경 (k3d) - Istio Gateway를 통한 통합 라우팅
    // Gateway port-forward 필요:
    //   kubectl port-forward svc/ecommerce-gateway-istio 8080:80 -n ecommerce &
    config.baseUrl = 'http://localhost:8080';
    config.gatewayHost = 'localhost';  // Istio Gateway 라우팅을 위한 Host 헤더
    // K3d 환경에서는 Kafka 이벤트 처리가 느릴 수 있으므로 재시도 설정 강화
    config.maxRetries = 30;       // 20 → 30 (비동기 이벤트 처리 대기)
    config.retryInterval = 3000;  // 2000 → 3000ms (Kafka consumer lag 고려)
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
    managerSignup: '/api/v1/auth/managers/signup',
    managerLogin: '/api/v1/auth/managers/login',
    managerLogout: '/api/v1/auth/managers/logout',
    tokenRefresh: '/api/v1/auth/refresh',

    // Store endpoints (store-api)
    stores: '/api/v1/stores',

    // Product endpoints (product-api)
    products: '/api/v1/products',

    // Order endpoints (order-api)
    orders: '/api/v1/orders',

    // Payment endpoints (payment-api)
    payments: '/api/v1/payments',

    // Saga Tracker endpoints (saga-tracker-api) - 비동기 처리 검증용
    sagas: '/api/v1/sagas'
  };

  // 서비스별 baseUrl 설정 - 모든 환경에서 Gateway를 통해 접근
  config.baseUrls = {
    customer: config.baseUrl,
    store: config.baseUrl,
    product: config.baseUrl,
    order: config.baseUrl,
    payment: config.baseUrl,
    sagaTracker: config.baseUrl  // Saga Tracker도 Gateway를 통해 접근
  };

  // PG Callback URL - 모든 환경에서 Gateway를 통해 접근
  config.pgCallbackBaseUrl = config.baseUrl;

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

  config.generateManagerEmail = function() {
    var id = java.util.UUID.randomUUID().toString().substring(0, 8);
    return 'manager-' + id + '@test.c4ang.com';
  };

  config.generateUsername = function() {
    var id = java.util.UUID.randomUUID().toString().substring(0, 8);
    return 'u' + id;
  };

  // Default test password
  config.testPassword = 'Test1234';

  return config;
}
