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
  // 모든 환경에서 Istio Gateway (ecommerce-gateway)를 통해 API 요청
  if (env === 'dev') {
    // 개발 환경 (k3d) - Istio Gateway를 통해 접근
    // port-forward로 istio-ingressgateway에 연결 (localhost:8080 -> istio-ingressgateway:80)
    config.baseUrl = 'http://localhost:8080';
    // Istio Gateway 라우팅을 위한 Host 헤더 (Gateway hostname과 일치해야 함)
    config.gatewayHost = 'api.ecommerce.com';
    // K3d 환경에서는 시작이 느릴 수 있으므로 재시도 횟수 증가
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

  // Service endpoints (모든 환경에서 동일한 경로 사용 - Gateway가 라우팅)
  config.services = {
    // Auth endpoints (customer-api로 라우팅)
    customerSignup: '/api/v1/auth/customers/signup',
    customerLogin: '/api/v1/auth/customers/login',
    customerLogout: '/api/v1/auth/customers/logout',
    ownerSignup: '/api/v1/auth/owners/signup',
    ownerLogin: '/api/v1/auth/owners/login',
    ownerLogout: '/api/v1/auth/owners/logout',
    tokenRefresh: '/api/v1/auth/refresh',

    // Store endpoints (store-api로 라우팅)
    stores: '/api/v1/stores',

    // Product endpoints (product-api로 라우팅)
    products: '/api/v1/products',

    // Order endpoints (order-api로 라우팅)
    orders: '/api/v1/orders',

    // Payment endpoints (payment-api로 라우팅)
    payments: '/api/v1/payments'
  };

  // Retry configuration for async operations
  karate.configure('retry', { count: config.maxRetries, interval: config.retryInterval });
  karate.configure('connectTimeout', config.apiTimeout);
  karate.configure('readTimeout', config.apiTimeout);

  // UUID generator helper
  config.uuid = function() {
    return java.util.UUID.randomUUID().toString();
  };

  // Timestamp helper
  config.timestamp = function() {
    return new Date().getTime();
  };

  // Test data generators
  config.generateCustomerEmail = function() {
    return 'customer-' + config.uuid().substring(0, 8) + '@test.c4ang.com';
  };

  config.generateOwnerEmail = function() {
    return 'owner-' + config.uuid().substring(0, 8) + '@test.c4ang.com';
  };

  config.generateUsername = function() {
    return 'u' + config.uuid().substring(0, 8);
  };

  // Default test password
  config.testPassword = 'Test1234';

  return config;
}
