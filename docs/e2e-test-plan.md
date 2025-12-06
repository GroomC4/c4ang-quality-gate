# E2E Test Plan - c4ang-quality-gate

## 1. Overview

### 1.1 Purpose
k3d 기반 Kubernetes 환경에서 MSA 서비스 전체의 API E2E 테스트 수행

### 1.2 Scope
| 항목 | 결정 |
|------|------|
| 테스트 유형 | API E2E Test (Karate) |
| 환경 | k3d only (로컬 + CI) |
| 범위 | Phase 1: Happy + Error → Phase 2: Full coverage |
| CI 전략 | Scheduled (야간) + Main merge |

### 1.3 Out of Scope
- UI 테스트 (프론트엔드 없음)
- 성능/부하 테스트 (별도 프로젝트)
- Chaos Engineering

---

## 2. Tech Stack

### 2.1 Framework: Karate + Kotlin Runner

| 구성 | 기술 | 역할 |
|------|------|------|
| Runner | Kotlin | 테스트 실행, 설정, 헬퍼 함수 |
| Scenario | Gherkin DSL (.feature) | 테스트 시나리오 작성 |
| Config | JavaScript | 환경별 설정 (karate-config.js) |
| Build | Gradle (Kotlin DSL) | 빌드 및 의존성 관리 |

### 2.2 Dependencies
```kotlin
// build.gradle.kts
dependencies {
    testImplementation("com.intuit.karate:karate-junit5:1.4.1")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.1")
    testImplementation("io.fabric8:kubernetes-client:6.9.2")
}
```

### 2.3 Why Karate?

**검토된 대안**
- REST Assured: Java 중심, BDD 가독성 부족
- Kotest + Ktor Client: 전체 Kotlin이나 비개발자 가독성 낮음
- Playwright: API 테스트는 부가 기능

**Karate 선택 이유**
- BDD 스타일로 시나리오 가독성 우수
- JSON/XML assertion 강력 지원
- Kotlin Runner로 프로젝트 일관성 유지
- API mock, 성능 테스트 재사용 가능

---

## 3. Target Services

### 3.1 Domain Services
| Service | Port | 핵심 기능 | 의존성 |
|---------|------|----------|--------|
| customer-service | 8081 | 인증, 회원관리 | - |
| store-service | 8082 | 스토어 CRUD | customer (Feign) |
| product-service | 8083 | 상품, 재고 | store (Feign), Kafka |
| order-service | 8084 | 주문 생성/취소 | store (Feign), Kafka |
| payment-service | 8085 | 결제 처리 | order (Feign), Kafka |

### 3.2 Infrastructure
| Component | 용도 |
|-----------|------|
| PostgreSQL | 각 서비스별 DB (5개) |
| Redis | 캐시, 분산 락 |
| Kafka + Schema Registry | 이벤트 스트리밍 |
| Istio Gateway | API Gateway, mTLS |

---

## 4. Test Scenarios

### 4.1 Phase 1: Happy Path + Major Error Cases

#### 4.1.1 Authentication Flow
```
[P1-AUTH-01] Customer 회원가입 → 로그인 → 토큰 발급
[P1-AUTH-02] Owner 회원가입 → 로그인 → 토큰 발급
[P1-AUTH-03] 토큰 갱신 (refresh token)
[P1-AUTH-04] 잘못된 비밀번호 → 401 에러
[P1-AUTH-05] 만료된 토큰 → 401 에러
```

#### 4.1.2 Store Flow
```
[P1-STORE-01] Owner 스토어 생성 → 조회
[P1-STORE-02] 스토어 정보 수정
[P1-STORE-03] 스토어 삭제 (soft delete)
[P1-STORE-04] 권한 없는 사용자 접근 → 403 에러
[P1-STORE-05] 존재하지 않는 스토어 → 404 에러
```

#### 4.1.3 Product Flow
```
[P1-PROD-01] 상품 등록 (스토어 검증 포함)
[P1-PROD-02] 상품 조회 (단건/목록/검색)
[P1-PROD-03] 상품 수정
[P1-PROD-04] 상품 삭제/숨김
[P1-PROD-05] 존재하지 않는 스토어에 상품 등록 → 에러
```

#### 4.1.4 Order Flow (SAGA)
```
[P1-ORDER-01] 주문 생성 → stock.reserved 이벤트 발행
[P1-ORDER-02] 재고 확인 후 주문 확정
[P1-ORDER-03] 주문 취소 → 보상 트랜잭션
[P1-ORDER-04] 재고 부족 시 주문 실패 → 보상 처리
[P1-ORDER-05] 결제 실패 시 주문 취소 → 재고 복구
```

#### 4.1.5 Payment Flow (SAGA)
```
[P1-PAY-01] 결제 요청 → payment.completed 이벤트
[P1-PAY-02] 결제 실패 → payment.failed 이벤트
[P1-PAY-03] 환불 요청 → 처리
[P1-PAY-04] 중복 결제 방지 (멱등성)
```

#### 4.1.6 Full Purchase Flow (E2E)
```
[P1-E2E-01] 회원가입 → 스토어생성 → 상품등록 → 주문 → 결제완료
[P1-E2E-02] 주문 → 결제실패 → 주문취소 (SAGA 보상)
[P1-E2E-03] 주문 → 결제완료 → 환불요청 → 환불완료
```

### 4.2 Phase 2: Full Coverage (향후)
- 모든 API 엔드포인트 커버
- 경계값 테스트
- 동시성 테스트 (낙관적 락)
- Kafka 이벤트 순서 보장 테스트

---

## 5. Test Structure

### 5.1 Directory Layout
```
src/test/
├── kotlin/com/c4ang/e2e/
│   ├── config/
│   │   └── TestConfig.kt           # K8s 연동, 환경설정
│   ├── runners/
│   │   ├── AuthServiceTest.kt      # 인증 테스트 러너
│   │   ├── StoreServiceTest.kt     # 스토어 테스트 러너
│   │   ├── ProductServiceTest.kt   # 상품 테스트 러너
│   │   ├── OrderServiceTest.kt     # 주문 테스트 러너
│   │   ├── PaymentServiceTest.kt   # 결제 테스트 러너
│   │   ├── SagaFlowTest.kt         # SAGA 시나리오 러너
│   │   └── AllTestsRunner.kt       # 전체 실행
│   └── helpers/
│       ├── AuthHelper.kt           # 토큰 관리
│       ├── DataFactory.kt          # 테스트 데이터 생성
│       └── KafkaHelper.kt          # Kafka 이벤트 검증
└── resources/
    ├── karate-config.js            # 환경별 설정
    └── features/
        ├── auth/
        │   ├── customer-signup.feature
        │   ├── owner-signup.feature
        │   ├── login.feature
        │   └── token-refresh.feature
        ├── store/
        │   ├── create-store.feature
        │   ├── get-store.feature
        │   ├── update-store.feature
        │   └── delete-store.feature
        ├── product/
        │   ├── register-product.feature
        │   ├── search-product.feature
        │   ├── update-product.feature
        │   └── delete-product.feature
        ├── order/
        │   ├── create-order.feature
        │   ├── cancel-order.feature
        │   └── order-saga-flow.feature
        ├── payment/
        │   ├── request-payment.feature
        │   ├── complete-payment.feature
        │   └── refund-payment.feature
        └── scenario/
            ├── full-purchase-flow.feature
            ├── saga-compensation-flow.feature
            └── refund-flow.feature
```

### 5.2 Feature File Convention
```gherkin
@service:order @priority:p1 @saga
Feature: 주문 생성 - SAGA 플로우

  Background:
    * url baseUrl
    * def auth = call read('classpath:features/auth/login.feature@owner')
    * header Authorization = 'Bearer ' + auth.token
    * header X-Idempotency-Key = java.util.UUID.randomUUID()

  @happy-path
  Scenario: [P1-ORDER-01] 주문 생성 성공
    # ... 테스트 내용

  @error-case
  Scenario: [P1-ORDER-04] 재고 부족 시 주문 실패
    # ... 테스트 내용
```

---

## 6. Environment Setup

### 6.1 Prerequisites
- Docker Desktop (k3d 실행)
- JDK 21
- kubectl, helm, k3d (자동 설치)

### 6.2 Infra Dependency
c4ang-infra를 서브모듈로 사용:
```bash
git submodule add ../c4ang-infra c4ang-infra
```

### 6.3 Cluster Bootstrap
```bash
# k3d 클러스터 + 전체 인프라 배포
./scripts/setup-test-env.sh

# 구성요소:
# - k3d cluster (Istio 포함)
# - PostgreSQL x 5 (서비스별)
# - Redis
# - Kafka + Schema Registry
# - 모든 MSA 서비스
```

### 6.4 Service Access
```
# Istio Gateway를 통한 접근 (테스트 대상)
http://localhost:8080/api/v1/*

# 직접 접근 (디버깅용)
kubectl port-forward svc/customer-service 8081:8080 -n ecommerce
```

---

## 7. CI/CD Integration

### 7.1 GitHub Actions Workflow

#### Main merge 시
```yaml
# .github/workflows/e2e-on-merge.yml
name: E2E Tests on Main

on:
  push:
    branches: [main]

jobs:
  e2e-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup k3d
        uses: nolar/setup-k3d-k3s@v1

      - name: Deploy Infrastructure
        run: ./scripts/setup-test-env.sh

      - name: Run E2E Tests
        run: ./gradlew test

      - name: Upload Report
        uses: actions/upload-artifact@v4
        with:
          name: karate-reports
          path: build/karate-reports/
```

#### Scheduled (야간)
```yaml
# .github/workflows/e2e-scheduled.yml
name: Scheduled E2E Tests

on:
  schedule:
    - cron: '0 15 * * *'  # 매일 00:00 KST

jobs:
  e2e-full:
    # ... 전체 테스트 실행
    # 실패 시 Slack 알림
```

### 7.2 External Trigger
서비스 레포에서 E2E 테스트 트리거:
```yaml
# order-service/.github/workflows/trigger-e2e.yml
- uses: peter-evans/repository-dispatch@v2
  with:
    repository: GroomC4/c4ang-quality-gate
    event-type: service-updated
    client-payload: '{"service": "order-service", "tag": "${{ github.sha }}"}'
```

---

## 8. Async Event Verification

MSA + Kafka 환경에서 비동기 상태 변경 검증 전략

### 8.1 Retry Until (Karate 내장)

가장 간단한 방법. karate-config.js에서 전역 설정:

```javascript
// karate-config.js
karate.configure('retry', { count: 15, interval: 1000 }); // 최대 15회, 1초 간격
```

```gherkin
Scenario: 주문 생성 후 SAGA 완료 대기
  # 주문 생성
  Given path '/api/v1/orders'
  And request { "storeId": "#(storeId)", "items": [...] }
  When method POST
  Then status 201
  * def orderId = response.id

  # retry until로 상태 변경 대기
  Given path '/api/v1/orders/' + orderId
  And retry until response.status == 'CONFIRMED'
  When method GET
  Then status 200
  And match response.status == 'CONFIRMED'
```

### 8.2 Polling Helper (재사용 가능)

복잡한 조건이나 타임아웃 처리가 필요한 경우:

```gherkin
# helpers/wait-status.feature
@ignore
Feature: 상태 대기 헬퍼

  Scenario: 상태 변경 대기
    * def targetUrl = __arg.url
    * def expectedStatus = __arg.expectedStatus
    * def maxWait = __arg.maxWait || 10000
    * def interval = __arg.interval || 1000

    * def pollStatus =
      """
      function() {
        var maxRetries = Math.floor(maxWait / interval);
        for (var i = 0; i < maxRetries; i++) {
          var res = karate.call(targetUrl);
          karate.log('Attempt', i + 1, '- Status:', res.response.status);
          if (res.response.status == expectedStatus) {
            return { success: true, data: res.response, attempts: i + 1 };
          }
          if (res.response.status.includes('FAILED')) {
            return { success: false, reason: res.response.status, data: res.response };
          }
          karate.pause(interval);
        }
        return { success: false, reason: 'TIMEOUT' };
      }
      """

    * def result = pollStatus()
```

**사용 예시:**
```gherkin
Scenario: Helper 사용
  * def result = call read('classpath:helpers/wait-status.feature')
    { url: 'classpath:features/order/get-order.feature', expectedStatus: 'CONFIRMED', maxWait: 15000 }
  * assert result.success == true
  * match result.data.status == 'CONFIRMED'
```

### 8.3 SAGA 전체 플로우 검증

```gherkin
@saga @async
Feature: 주문-결제 SAGA 플로우

  Background:
    * url baseUrl
    * def auth = call read('classpath:features/auth/login.feature@customer')
    * header Authorization = 'Bearer ' + auth.token
    * configure retry = { count: 15, interval: 1000 }

  Scenario: [P1-E2E-01] 주문 → 재고예약 → 결제 → 완료
    # Step 1: 주문 생성 (ORDER_CREATED)
    Given path '/api/v1/orders'
    And request
      """
      {
        "storeId": "#(testStore.id)",
        "items": [{ "productId": "#(testProduct.id)", "quantity": 2 }]
      }
      """
    When method POST
    Then status 201
    And match response.status == 'ORDER_CREATED'
    * def orderId = response.id

    # Step 2: 재고 예약 완료 대기 (stock.reserved → order.confirmed)
    Given path '/api/v1/orders/' + orderId
    And retry until response.status == 'ORDER_CONFIRMED' || response.status == 'ORDER_FAILED'
    When method GET
    Then status 200
    And match response.status == 'ORDER_CONFIRMED'

    # Step 3: 결제 요청
    Given path '/api/v1/payments/request'
    And request { "orderId": "#(orderId)", "method": "CARD" }
    When method POST
    Then status 201
    * def paymentId = response.id

    # Step 4: 결제 완료 대기 (payment.completed → order 상태 업데이트)
    Given path '/api/v1/orders/' + orderId
    And retry until response.status == 'PAYMENT_COMPLETED'
    When method GET
    Then status 200
    And match response.status == 'PAYMENT_COMPLETED'
```

### 8.4 실패 케이스 검증 (SAGA 보상)

```gherkin
@saga @compensation
Scenario: [P1-E2E-02] 재고 부족 → 주문 실패 → 보상 트랜잭션
  # 재고가 부족한 상품으로 주문
  Given path '/api/v1/orders'
  And request
    """
    {
      "storeId": "#(testStore.id)",
      "items": [{ "productId": "#(outOfStockProduct.id)", "quantity": 9999 }]
    }
    """
  When method POST
  Then status 201
  * def orderId = response.id

  # 재고 예약 실패 → 주문 실패 상태 확인
  Given path '/api/v1/orders/' + orderId
  And retry until response.status == 'ORDER_FAILED' || response.status == 'ORDER_CONFIRMED'
  When method GET
  Then status 200
  And match response.status == 'ORDER_FAILED'
  And match response.failReason == 'STOCK_RESERVATION_FAILED'
```

### 8.5 타임아웃 설정 가이드

| 이벤트 흐름 | 예상 소요 | 권장 타임아웃 |
|------------|----------|--------------|
| 단일 서비스 API | < 1초 | 5초 |
| 재고 예약 (order→product) | 1~3초 | 10초 |
| 결제 처리 (order→payment) | 2~5초 | 15초 |
| 전체 SAGA 플로우 | 5~10초 | 30초 |

### 8.6 Event Topics Reference
| Event | Topic | Producer | Expected Consumer Action |
|-------|-------|----------|-------------------------|
| OrderCreated | order.created | order | product: 재고 예약 |
| StockReserved | stock.reserved | product | order: 상태 업데이트 |
| OrderConfirmed | order.confirmed | order | payment: 결제 대기 |
| PaymentCompleted | payment.completed | payment | order: 주문 완료 |
| PaymentFailed | payment.failed | payment | order/product: 보상 |

---

## 9. Test Data Management

### 9.1 Data Isolation
- 각 테스트는 고유한 데이터 생성 (UUID 기반)
- 테스트 후 cleanup 불필요 (k3d 재생성)

### 9.2 Test User Convention
```javascript
// karate-config.js
config.testUsers = {
  customer: { email: 'customer-{uuid}@test.com', password: 'Test1234!' },
  owner: { email: 'owner-{uuid}@test.com', password: 'Test1234!' }
};
```

### 9.3 Shared Test Data
```
config/
├── service-versions.yaml    # 서비스 이미지 태그
└── test-data/
    ├── products.json        # 샘플 상품 데이터
    └── stores.json          # 샘플 스토어 데이터
```

---

## 10. Reporting

### 10.1 Karate Report
```bash
# HTML 리포트
build/karate-reports/karate-summary.html

# JUnit XML (CI 연동)
build/test-results/test/*.xml
```

### 10.2 Report Content
- 시나리오별 Pass/Fail
- 요청/응답 상세
- 실행 시간
- 스크린샷 (실패 시)

---

## 11. Migration Plan

### 11.1 Current State
- customer-service 테스트만 존재
- 구 API 스펙 기반 (변경 필요)

### 11.2 Migration Steps

#### Step 1: 인프라 정비
- [ ] c4ang-infra 서브모듈 업데이트
- [ ] setup-test-env.sh 스크립트 수정
- [ ] karate-config.js 서비스 엔드포인트 업데이트

#### Step 2: Auth 테스트 마이그레이션
- [ ] customer-signup.feature (Customer 회원가입)
- [ ] owner-signup.feature (Owner 회원가입)
- [ ] login.feature 수정 (실제 API 스펙 반영)
- [ ] token-refresh.feature

#### Step 3: Store 테스트 작성
- [ ] create-store.feature
- [ ] get-store.feature
- [ ] update-store.feature
- [ ] delete-store.feature

#### Step 4: Product 테스트 작성
- [ ] register-product.feature
- [ ] search-product.feature
- [ ] update-product.feature

#### Step 5: Order 테스트 작성
- [ ] create-order.feature
- [ ] cancel-order.feature
- [ ] order-saga-flow.feature (SAGA 검증)

#### Step 6: Payment 테스트 작성
- [ ] request-payment.feature
- [ ] complete-payment.feature
- [ ] refund-payment.feature

#### Step 7: E2E 시나리오
- [ ] full-purchase-flow.feature
- [ ] saga-compensation-flow.feature

#### Step 8: CI/CD 구성
- [ ] e2e-on-merge.yml
- [ ] e2e-scheduled.yml
- [ ] External trigger 지원

---

## 12. Success Criteria

### 12.1 Phase 1 완료 조건
- [ ] 모든 서비스 Happy Path 테스트 통과
- [ ] 주요 Error Case 테스트 통과
- [ ] SAGA 플로우 (주문→결제) 테스트 통과
- [ ] CI 파이프라인 안정적 실행

### 12.2 Quality Metrics
| Metric | Target |
|--------|--------|
| Test Pass Rate | > 95% |
| CI 실행 시간 | < 15분 |
| Flaky Test Rate | < 5% |
