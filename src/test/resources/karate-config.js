function fn() {
  var env = karate.env;
  karate.log('karate.env system property was:', env);

  if (!env) {
    env = 'local';
  }

  var config = {
    env: env,
    apiTimeout: 30000,
    retryInterval: 1000,
    maxRetries: 15
  };

  // Environment-specific configuration
  if (env === 'local') {
    // 로컬 개발 환경 - 각 서비스가 개별 포트에서 실행
    config.baseUrl = 'http://localhost:8082';  // customer-service
    config.customerServiceUrl = 'http://localhost:8082';
    config.storeServiceUrl = 'http://localhost:8083';
    config.productServiceUrl = 'http://localhost:8084';
    config.orderServiceUrl = 'http://localhost:8085';
    config.paymentServiceUrl = 'http://localhost:8086';
    config.namespace = 'ecommerce';
    config.clusterDomain = 'cluster.local';
  } else if (env === 'dev') {
    config.baseUrl = 'http://api.c4ang.dev';
    config.namespace = 'ecommerce';
  } else if (env === 'prod') {
    config.baseUrl = 'https://api.c4ang.com';
    config.namespace = 'ecommerce';
  }

  // Common headers
  config.headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  };

  // Service endpoints
  config.services = {
    // Auth endpoints (customer-service)
    customerSignup: '/api/v1/auth/customers/signup',
    customerLogin: '/api/v1/auth/customers/login',
    customerLogout: '/api/v1/auth/customers/logout',
    ownerSignup: '/api/v1/auth/owners/signup',
    ownerLogin: '/api/v1/auth/owners/login',
    ownerLogout: '/api/v1/auth/owners/logout',
    tokenRefresh: '/api/v1/auth/refresh',

    // Store endpoints (store-service)
    stores: '/api/v1/stores',

    // Product endpoints (product-service)
    products: '/api/v1/products',

    // Order endpoints (order-service)
    orders: '/api/v1/orders',

    // Payment endpoints (payment-service)
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
