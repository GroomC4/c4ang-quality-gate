function fn() {
  var env = karate.env; // get system property 'karate.env'
  karate.log('karate.env system property was:', env);

  if (!env) {
    env = 'local';
  }

  var config = {
    env: env,
    apiTimeout: 30000,
    retryInterval: 2000,
    maxRetries: 3
  };

  // Environment-specific configuration
  if (env === 'local') {
    // K3d 로컬 환경 (NodePort 또는 Port-Forward)
    config.baseUrl = 'http://localhost:8080';
    config.namespace = 'msa-quality';
    config.clusterDomain = 'cluster.local';
  } else if (env === 'dev') {
    // 개발 환경 (Ingress)
    config.baseUrl = 'http://api.c4ang.com';
    config.namespace = 'msa-quality';
  } else if (env === 'staging') {
    // 스테이징 환경
    config.baseUrl = 'http://api-staging.c4ang.com';
    config.namespace = 'msa-quality-staging';
  } else if (env === 'prod') {
    // 프로덕션 환경
    config.baseUrl = 'https://api.c4ang.com';
    config.namespace = 'msa-quality-prod';
  }

  // Common headers
  config.headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  };

  // JWT 토큰 획득 헬퍼 함수
  config.getAuthToken = function(username, password) {
    var loginUrl = config.baseUrl + '/api/v1/auth/login';
    var response = karate.call('classpath:features/auth/login.feature', {
      username: username,
      password: password
    });
    return response.token;
  };

  // 기본 테스트 사용자 계정 (환경변수로 오버라이드 가능)
  config.testUser = {
    username: karate.properties['test.user.username'] || 'test@c4ang.com',
    password: karate.properties['test.user.password'] || 'testPassword123!'
  };

  // 서비스별 엔드포인트 (동적 서비스 추가 지원)
  config.services = {
    auth: config.baseUrl + '/api/v1/auth',
    customer: config.baseUrl + '/api/v1/customers',
    // 다른 서비스들이 추가될 예정
    // order: config.baseUrl + '/api/v1/orders',
    // payment: config.baseUrl + '/api/v1/payments',
  };

  // Kubernetes 서비스 내부 엔드포인트 (서비스 간 통신 테스트용)
  config.internalServices = {
    customer: 'http://customer-service.' + config.namespace + '.svc.' + config.clusterDomain + ':8080'
  };

  karate.configure('connectTimeout', config.apiTimeout);
  karate.configure('readTimeout', config.apiTimeout);
  karate.configure('retry', { count: config.maxRetries, interval: config.retryInterval });

  return config;
}
