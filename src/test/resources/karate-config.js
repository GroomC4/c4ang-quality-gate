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
    // 각 서비스별 포트: customer-api(8081), store-api(8082), product-api(8083), order-api(8084), payment-api(8085)
    config.customerApiUrl = 'http://localhost:8081';
    config.storeApiUrl = 'http://localhost:8082';
    config.productApiUrl = 'http://localhost:8083';
    config.orderApiUrl = 'http://localhost:8084';
    config.paymentApiUrl = 'http://localhost:8085';
    // 기본 baseUrl은 customer-api (인증 테스트용)
    config.baseUrl = config.customerApiUrl;
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

  // Service endpoints
  // CI 환경에서는 각 서비스별 URL 사용, 그 외 환경에서는 Gateway 라우팅 사용
  if (env === 'ci') {
    // CI 환경: 각 서비스로 직접 접근
    config.services = {
      // Auth endpoints (customer-api - port 8081)
      customerSignup: config.customerApiUrl + '/api/v1/auth/customers/signup',
      customerLogin: config.customerApiUrl + '/api/v1/auth/customers/login',
      customerLogout: config.customerApiUrl + '/api/v1/auth/customers/logout',
      ownerSignup: config.customerApiUrl + '/api/v1/auth/owners/signup',
      ownerLogin: config.customerApiUrl + '/api/v1/auth/owners/login',
      ownerLogout: config.customerApiUrl + '/api/v1/auth/owners/logout',
      tokenRefresh: config.customerApiUrl + '/api/v1/auth/refresh',

      // Store endpoints (store-api - port 8082)
      stores: config.storeApiUrl + '/api/v1/stores',

      // Product endpoints (product-api - port 8083)
      products: config.productApiUrl + '/api/v1/products',

      // Order endpoints (order-api - port 8084)
      orders: config.orderApiUrl + '/api/v1/orders',

      // Payment endpoints (payment-api - port 8085)
      payments: config.paymentApiUrl + '/api/v1/payments'
    };
  } else {
    // dev/prod 환경: Gateway 라우팅 사용 (상대 경로)
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
