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
  if (env === 'ci') {
    // CI 환경 (k3d) - Istio Gateway 없이 각 서비스로 직접 port-forward
    // 포트 18081-18085 사용 (8081은 schema-registry가 사용하므로 충돌 방지)
    // 각 서비스별 포트: customer-api(18081), store-api(18082), product-api(18083), order-api(18084), payment-api(18085)
    // baseUrl은 customer-api로 설정 (대부분의 테스트가 auth로 시작)
    config.baseUrl = 'http://localhost:18081';
    // 서비스별 baseUrl (feature에서 url을 변경할 때 사용)
    config.baseUrls = {
      customer: 'http://localhost:18081',
      store: 'http://localhost:18082',
      product: 'http://localhost:18083',
      order: 'http://localhost:18084',
      payment: 'http://localhost:18085'
    };
    // CI 환경에서는 시작이 느릴 수 있으므로 재시도 횟수 증가
    config.maxRetries = 20;
    config.retryInterval = 2000;
  } else if (env === 'dev') {
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

  // Service endpoints - 모든 환경에서 상대 경로 사용
  // CI 환경에서는 feature 파일에서 baseUrls를 사용해 서비스별 URL 선택
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

  // dev/prod 환경에서는 baseUrls를 baseUrl과 동일하게 설정 (모든 서비스가 Gateway를 통해 접근)
  if (env !== 'ci') {
    config.baseUrls = {
      customer: config.baseUrl,
      store: config.baseUrl,
      product: config.baseUrl,
      order: config.baseUrl,
      payment: config.baseUrl
    };
  }

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
