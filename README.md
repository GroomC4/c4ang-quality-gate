# c4ang-quality-gate

E-Commerce MSA 시스템의 E2E 시나리오 테스트를 담당하는 Quality Gate 프로젝트입니다.

K3d로 구축한 Kubernetes 환경에서 Karate 프레임워크를 사용하여 마이크로서비스 간 통합 테스트를 자동화합니다.

## 📋 개요

이 프로젝트는 다음을 제공합니다:

- **K3d 기반 로컬 K8s 환경**: 운영과 유사한 Istio Service Mesh 환경에서 테스트
- **Karate E2E 테스트**: BDD 스타일의 API 시나리오 테스트
- **JUnit 5 통합**: IDE 및 CI/CD 파이프라인 지원
- **자동화 스크립트**: 환경 구축부터 정리까지 원클릭 실행
- **GitHub Actions CI/CD**: PR 및 푸시 시 자동 테스트 실행
- **분산 추적 및 모니터링**: Jaeger, Prometheus, Grafana Loki 통합

## 🏗️ 프로젝트 구조

```
c4ang-quality-gate/
├── src/
│   └── test/
│       ├── kotlin/
│       │   └── com/c4ang/e2e/
│       │       ├── config/
│       │       │   └── TestConfig.kt          # K8s 연동 설정
│       │       ├── runners/
│       │       │   ├── UserServiceTest.kt      # User Service 테스트
│       │       │   ├── StoreServiceTest.kt     # Store Service 테스트
│       │       │   ├── ProductServiceTest.kt   # Product Service 테스트
│       │       │   ├── OrderServiceTest.kt     # Order Service 테스트
│       │       │   ├── PaymentServiceTest.kt   # Payment Service 테스트
│       │       │   ├── E2EScenarioTest.kt      # E2E 시나리오 러너
│       │       │   └── AllTestsRunner.kt       # 전체 테스트 러너
│       │       └── TestLifecycleHooks.kt       # 테스트 라이프사이클
│       └── resources/
│           ├── karate-config.js                # Karate 글로벌 설정
│           ├── logback-test.xml                # 로깅 설정
│           └── features/                       # Karate Feature 파일
│               ├── auth/
│               │   └── login.feature           # 인증/로그인 테스트
│               ├── user/                       # User Service 테스트
│               ├── store/                      # Store Service 테스트
│               ├── product/                    # Product Service 테스트
│               ├── order/                      # Order Service 테스트
│               ├── payment/                    # Payment Service 테스트
│               └── scenario/
│                   ├── end-to-end-order-flow.feature
│                   └── multi-service-integration.feature
├── scripts/
│   ├── setup-test-env.sh                       # 테스트 환경 구축
│   ├── run-tests.sh                            # 테스트 실행
│   ├── set-image-tag.sh                        # 서비스 이미지 태그 설정
│   └── teardown-test-env.sh                    # 환경 정리
├── config/
│   ├── service-versions.yaml                   # 서비스 버전 관리
│   └── test-overrides.yaml                     # 테스트 환경 설정
├── docs/
│   ├── trigger-from-external-repo.md           # 외부 레포 트리거 가이드
│   └── system-architecture.md                  # 시스템 아키텍처 문서
├── c4ang-infra/                                # 인프라 설정 서브모듈
├── build.gradle.kts                            # Gradle 빌드 설정
└── README.md
```

## 🎯 테스트 대상 서비스

### 핵심 비즈니스 서비스
- **User Service**: 회원가입, 로그인, 프로필 관리
- **Authorization Service**: 역할, 권한, 접근 제어
- **Store Service**: 상점 생성, 수정, 출시
- **Product Service**: 상품 등록, 재고 관리, 메타데이터 관리
- **Order Service**: 주문 생성, 취소, 조회
- **Payment Service**: 결제 요청, 완료, 환불
- **Review Service**: 리뷰 작성, 조회, 평점

### 지원 서비스
- **Recommendation Service**: 유사 상품 추천, 개인화 추천
- **Analytics Service**: 사용자 행동 데이터 수집, 통계 집계
- **Saga Tracker Service**: 분산 트랜잭션 모니터링

## 🚀 빠른 시작

### 사전 요구사항

- **Docker Desktop**: K3d 실행을 위해 필요
- **JDK 17**: Java/Kotlin 실행
- **Homebrew** (macOS): k3d, kubectl, Helm 자동 설치
- **yq** (선택): 서비스 버전 관리 (`brew install yq`)

### 1. 저장소 클론 및 서브모듈 초기화

```bash
git clone https://github.com/GroomC4/c4ang-quality-gate.git
cd c4ang-quality-gate
git submodule update --init --recursive
```

### 2. 테스트할 서비스 버전 설정 (선택)

특정 버전의 서비스를 테스트하려면:

```bash
# 방법 1: 스크립트 사용
./scripts/set-image-tag.sh user-service v1.0.0
./scripts/set-image-tag.sh order-service v1.0.0

# 방법 2: 환경변수 사용
export USER_SERVICE_TAG=v1.0.0
export ORDER_SERVICE_TAG=v1.0.0

# 방법 3: config/service-versions.yaml 직접 편집
```

### 3. 테스트 환경 구축

K3d 클러스터 생성 및 인프라 배포 (PostgreSQL, Redis 등):

```bash
./scripts/setup-test-env.sh
```

이 스크립트는 다음을 수행합니다:
- k3d, kubectl, Helm 자동 설치 (필요시)
- K3d 클러스터 생성 (Istio Service Mesh 포함)
- PostgreSQL, Redis, Kafka 배포
- MSA 서비스 배포 (User, Store, Product, Order, Payment 등)
- 모니터링 스택 배포 (Prometheus, Grafana, Jaeger, Loki)

### 4. E2E 테스트 실행

```bash
./scripts/run-tests.sh
```

특정 테스트만 실행:

```bash
# User Service 테스트만
./scripts/run-tests.sh -t UserServiceTest

# Order Service 테스트만
./scripts/run-tests.sh -t OrderServiceTest

# E2E 시나리오 테스트만
./scripts/run-tests.sh -t E2EScenarioTest

# 모든 테스트 실행
./scripts/run-tests.sh -t AllTestsRunner
```

또는 Gradle 직접 사용:

```bash
./gradlew test                                  # 모든 테스트
./gradlew test --tests UserServiceTest         # User Service 테스트
./gradlew test --tests OrderServiceTest        # Order Service 테스트
./gradlew test --tests "*.E2EScenarioTest"     # E2E 시나리오 테스트
```

### 5. 테스트 리포트 확인

```bash
# HTML 리포트
open build/karate-reports/karate-summary.html

# JUnit 리포트
open build/reports/tests/test/index.html
```

### 6. 환경 정리

```bash
# 대화형으로 선택
./scripts/teardown-test-env.sh

# 환경 중지 (재시작 가능)
./scripts/teardown-test-env.sh --stop

# 클러스터 삭제
./scripts/teardown-test-env.sh --delete

# 완전 정리
./scripts/teardown-test-env.sh --full
```

## 🧪 테스트 작성 가이드

### 시스템 아키텍처 이해

E2E 테스트는 실제 운영 환경과 유사한 구조로 실행됩니다:

- **API Gateway**: Istio Gateway (mTLS, JWT 인증, Rate Limiting)
- **Service Mesh**: Istio (분산 추적, 메트릭 수집)
- **Event Streaming**: Kafka (비동기 통신, Saga Choreography)
- **Monitoring**: Prometheus + Grafana + Jaeger + Loki
- **Database**: 각 서비스별 독립 PostgreSQL

자세한 내용은 [시스템 아키텍처 문서](./docs/system-architecture.md)를 참고하세요.

### Feature 파일 작성 (Karate)

새로운 서비스 테스트를 추가하려면:

1. `src/test/resources/features/{service-name}/` 디렉토리 생성
2. Feature 파일 작성 (예: `create-order.feature`)

```gherkin
Feature: 주문 서비스 - 주문 생성

  Background:
    * url baseUrl
    * def orderEndpoint = services.order
    # JWT 토큰 획득 (User Service 인증)
    * def loginResponse = call read('classpath:features/auth/login.feature') { username: '#(testUser.username)', password: '#(testUser.password)' }
    * def authToken = loginResponse.token
    * header Authorization = 'Bearer ' + authToken

  Scenario: 새 주문 생성 성공 (Saga Choreography)
    Given path '/api/v1/orders'
    And request
      """
      {
        "storeId": "store-123",
        "items": [
          { "productId": "prod-001", "quantity": 2 }
        ]
      }
      """
    When method POST
    Then status 201
    And match response.id == '#string'
    And match response.status == 'CREATED'
    # Saga 이벤트 추적 (비동기)
    * def orderId = response.id
    * karate.pause(2000)  # Kafka 이벤트 처리 대기
```

3. JUnit 러너 작성 (Kotlin)

```kotlin
// src/test/kotlin/com/c4ang/e2e/runners/OrderServiceTest.kt
class OrderServiceTest : TestLifecycleHooks() {

    @Karate.Test
    fun testCreateOrder(): Karate {
        return Karate.run("classpath:features/order/create-order.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testOrderSagaFlow(): Karate {
        return Karate.run("classpath:features/order/order-saga-flow.feature")
            .relativeTo(javaClass)
    }
}
```

### E2E 시나리오 테스트 (Saga Choreography)

여러 서비스를 통합한 플로우 테스트 (Kafka 이벤트 기반):

```gherkin
Feature: E2E 시나리오 - 주문 전체 플로우 (Saga Pattern)

  Scenario: 회원가입 → 상점 생성 → 상품 등록 → 주문 → 결제 (분산 트랜잭션)
    # Step 1: 회원가입 (User Service)
    Given path '/api/v1/users/register'
    And request { "email": "test@example.com", "password": "password123" }
    When method POST
    Then status 201
    * def userId = response.id

    # Step 2: 로그인 및 토큰 획득
    * def authToken = call read('classpath:features/auth/login.feature') { username: 'test@example.com', password: 'password123' }

    # Step 3: 상점 생성 (Store Service)
    Given path '/api/v1/stores'
    And header Authorization = 'Bearer ' + authToken.token
    And request { "name": "테스트상점", "ownerId": "#(userId)" }
    When method POST
    Then status 201
    * def storeId = response.id

    # Step 4: 상품 등록 (Product Service)
    Given path '/api/v1/products'
    And header Authorization = 'Bearer ' + authToken.token
    And request { "name": "테스트상품", "price": 10000, "stock": 100, "storeId": "#(storeId)" }
    When method POST
    Then status 201
    * def productId = response.id
    # ProductCreatedEvent → Kafka → Recommendation Service (비동기)

    # Step 5: 주문 생성 (Order Service)
    Given path '/api/v1/orders'
    And header Authorization = 'Bearer ' + authToken.token
    And request { "storeId": "#(storeId)", "items": [{ "productId": "#(productId)", "quantity": 2 }] }
    When method POST
    Then status 201
    * def orderId = response.id
    # OrderCreatedEvent → Kafka → Product Service (재고 예약)

    # Step 6: 결제 (Payment Service)
    * karate.pause(1000)  # Kafka 이벤트 처리 대기
    Given path '/api/v1/payments'
    And header Authorization = 'Bearer ' + authToken.token
    And request { "orderId": "#(orderId)", "amount": 20000, "method": "CARD" }
    When method POST
    Then status 201
    # PaymentCompletedEvent → Kafka → Order Service (주문 확정)

    # Step 7: 주문 상태 확인 (Saga 완료)
    * karate.pause(2000)  # Kafka 이벤트 전파 대기
    Given path '/api/v1/orders/' + orderId
    And header Authorization = 'Bearer ' + authToken.token
    When method GET
    Then status 200
    And match response.status == 'CONFIRMED'

    # Step 8: Saga Tracker 확인 (선택적)
    Given path '/api/v1/sagas/order/' + orderId
    When method GET
    Then status 200
    And match response.sagaStatus == 'COMPLETED'
```

## 🔧 환경별 설정

### karate-config.js에서 환경 설정

```javascript
// local 환경 (기본)
if (env === 'local') {
  config.baseUrl = 'http://localhost:8080';
  config.namespace = 'msa-quality';
}

// dev 환경
else if (env === 'dev') {
  config.baseUrl = 'http://api.c4ang.com';
  config.namespace = 'msa-quality';
}
```

테스트 실행 시 환경 지정:

```bash
./scripts/run-tests.sh -e dev
# 또는
./gradlew test -Dkarate.env=dev
```

## 🎛️ 서비스 버전 제어

### 서브모듈 변경 없이 이미지 태그 제어

테스트할 서비스의 특정 버전을 지정할 수 있습니다:

#### 방법 1: 설정 파일 사용

```bash
# 스크립트로 설정
./scripts/set-image-tag.sh user-service v1.2.0
./scripts/set-image-tag.sh order-service v1.3.0

# 또는 config/service-versions.yaml 직접 편집
services:
  user-service:
    image:
      tag: "v1.2.0"  # 원하는 버전으로 변경
  order-service:
    image:
      tag: "v1.3.0"
```

#### 방법 2: 환경변수 사용

```bash
export USER_SERVICE_TAG=v1.2.0
export ORDER_SERVICE_TAG=v1.3.0
./scripts/setup-test-env.sh
```

#### 방법 3: Helm --set 플래그

```bash
# setup-test-env.sh 스크립트가 자동으로 처리
# config/test-overrides.yaml의 설정도 함께 적용됨
```

### 여러 서비스 버전 동시 관리

```yaml
# config/service-versions.yaml
services:
  user-service:
    image:
      tag: "v1.2.0"
  store-service:
    image:
      tag: "v1.0.0"
  product-service:
    image:
      tag: "develop-abc123"
  order-service:
    image:
      tag: "v2.0.0"
  payment-service:
    image:
      tag: "latest"
    enabled: false  # 테스트에서 제외
```

---

## 🔄 CI/CD 워크플로우

### GitHub Actions

#### 1. 기본 E2E 테스트 (PR/Push)

```yaml
# .github/workflows/e2e-tests.yml
- Push/PR → 환경 구축 → E2E 테스트 실행 → 리포트 업로드
```

#### 2. 스케줄링된 테스트

```yaml
# .github/workflows/scheduled-e2e.yml
- 매일 오전 9시 (KST) 자동 실행
- Slack 알림 (실패 시)
```

#### 3. 외부 레포에서 트리거 ⭐ NEW

다른 서비스 레포(예: user-service, order-service)에서 이 프로젝트의 E2E 테스트를 트리거할 수 있습니다.

**서비스 레포에서 설정:**

```yaml
# user-service/.github/workflows/trigger-e2e.yml
- name: Trigger E2E tests
  uses: peter-evans/repository-dispatch@v2
  with:
    token: ${{ secrets.E2E_TRIGGER_TOKEN }}
    repository: GroomC4/c4ang-quality-gate
    event-type: trigger-e2e-test
    client-payload: |
      {
        "service_name": "user-service",
        "image_tag": "v1.0.0",
        "test_suite": "UserServiceTest",
        "pr_number": "${{ github.event.number }}"
      }
```

**결과:**
- c4ang-quality-gate에서 E2E 테스트 자동 실행
- 테스트 결과가 원본 PR에 자동 코멘트됨
- 실패 시 원본 레포로 알림

자세한 가이드: [외부 레포에서 트리거하기](./docs/trigger-from-external-repo.md)

## 📦 새로운 서비스 추가

새 MSA 서비스 (예: `review-service`)가 추가될 때:

1. **인프라 레포에서 Helm 차트 추가**
   ```bash
   c4ang-infra/helm/services/review-service/
   ├── Chart.yaml
   ├── values.yaml
   └── templates/
       ├── deployment.yaml
       ├── service.yaml
       └── ...
   ```

2. **karate-config.js 업데이트**
   ```javascript
   config.services = {
     auth: config.baseUrl + '/api/v1/auth',
     user: config.baseUrl + '/api/v1/users',
     store: config.baseUrl + '/api/v1/stores',
     product: config.baseUrl + '/api/v1/products',
     order: config.baseUrl + '/api/v1/orders',
     payment: config.baseUrl + '/api/v1/payments',
     review: config.baseUrl + '/api/v1/reviews',  // 추가
   };
   ```

3. **Feature 파일 작성**
   ```bash
   src/test/resources/features/review/
   ├── create-review.feature
   ├── get-review.feature
   ├── update-review.feature
   └── delete-review.feature
   ```

4. **JUnit 러너 작성**
   ```kotlin
   // src/test/kotlin/com/c4ang/e2e/runners/ReviewServiceTest.kt
   class ReviewServiceTest : TestLifecycleHooks() {
       @Karate.Test
       fun testCreateReview(): Karate {
           return Karate.run("classpath:features/review/create-review.feature")
               .relativeTo(javaClass)
       }
   }
   ```

5. **서비스 버전 설정 파일 업데이트**
   ```yaml
   # config/service-versions.yaml
   services:
     review-service:
       image:
         repository: c4ang/review-service
         tag: "latest"
       enabled: true
   ```

6. **배포 스크립트 업데이트** (필요시)
   ```bash
   scripts/setup-test-env.sh
   # deploy_msa_services() 함수에 review-service 배포 로직 추가
   ```

### 서비스 추가 후 확인사항

- [ ] Kafka 이벤트 연동 확인 (ReviewCreatedEvent 등)
- [ ] Istio mTLS 통신 확인
- [ ] Prometheus 메트릭 수집 확인 (`/actuator/prometheus`)
- [ ] Jaeger 분산 추적 확인 (Trace ID 전파)
- [ ] Loki 로그 수집 확인 (`{service="review-service"}`)
- [ ] Saga Tracker 통합 (필요시)

## 🛠️ 문제 해결

### 포트 충돌

```bash
# 포트 확인
lsof -i :80
lsof -i :443
lsof -i :6443

# 다른 포트 범위 사용
export NODEPORT_START=30100
export NODEPORT_END=30200
./scripts/setup-test-env.sh
```

### 클러스터 재생성

```bash
./scripts/teardown-test-env.sh --delete
./scripts/setup-test-env.sh
```

### Pod 상태 확인

```bash
export KUBECONFIG=c4ang-infra/k8s-dev-k3d/kubeconfig/config
kubectl get pods -n msa-quality
kubectl logs <pod-name> -n msa-quality
kubectl describe pod <pod-name> -n msa-quality
```

### 테스트 디버깅

```bash
# Karate 디버그 모드
./gradlew test -Dkarate.options="--tags @debug" --info

# 특정 Feature만 실행
./gradlew test --tests UserServiceTest.testRegister

# Jaeger로 분산 추적 확인
# Jaeger UI: http://localhost:16686 (port-forward 필요)
kubectl port-forward -n msa-quality svc/jaeger 16686:16686

# Grafana로 로그 및 메트릭 확인
# Grafana UI: http://localhost:3000 (port-forward 필요)
kubectl port-forward -n msa-quality svc/grafana 3000:3000
```

### Kafka 이벤트 확인

```bash
# Kafka Pod 접속
kubectl exec -it -n msa-quality kafka-0 -- bash

# Topic 리스트 확인
kafka-topics.sh --bootstrap-server localhost:9092 --list

# 이벤트 확인
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic order-events \
  --from-beginning

# Consumer Group Lag 확인
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group order-service \
  --describe
```

### 모니터링 스택 확인

```bash
# Prometheus 메트릭 확인
kubectl port-forward -n msa-quality svc/prometheus 9090:9090
# http://localhost:9090

# Grafana 대시보드
kubectl port-forward -n msa-quality svc/grafana 3000:3000
# http://localhost:3000 (admin/admin)

# Jaeger 분산 추적
kubectl port-forward -n msa-quality svc/jaeger 16686:16686
# http://localhost:16686

# Loki 로그 쿼리
# Grafana Explore → Loki → {service="order-service"}
```

### Saga Tracker 확인

```bash
# Saga 상태 조회
kubectl port-forward -n msa-quality svc/saga-tracker-service 8080:8080
curl http://localhost:8080/api/v1/sagas/order/{orderId}

# Saga 이벤트 히스토리
curl http://localhost:8080/api/v1/sagas/order/{orderId}/events
```

## 📚 참고 자료

### 내부 문서
- [시스템 아키텍처](./docs/system-architecture.md) - E-Commerce MSA 전체 아키텍처
- [외부 레포 트리거 가이드](./docs/trigger-from-external-repo.md)
- [c4ang-infra README](./c4ang-infra/README.md)
- [k3d 환경 가이드](./c4ang-infra/k8s-dev-k3d/README.md)

### 외부 문서

#### 테스트 프레임워크
- [Karate 공식 문서](https://github.com/karatelabs/karate)
- [JUnit 5 공식 문서](https://junit.org/junit5/docs/current/user-guide/)

#### 인프라
- [k3d 공식 문서](https://k3d.io/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [Istio 공식 문서](https://istio.io/latest/docs/)
- [Helm 공식 문서](https://helm.sh/docs/)

#### 모니터링 및 관찰성
- [Prometheus 공식 문서](https://prometheus.io/docs/)
- [Grafana 공식 문서](https://grafana.com/docs/)
- [Grafana Loki 공식 문서](https://grafana.com/docs/loki/latest/)
- [Jaeger 공식 문서](https://www.jaegertracing.io/docs/)
- [OpenTelemetry 공식 문서](https://opentelemetry.io/docs/)

#### 이벤트 스트리밍
- [Apache Kafka 공식 문서](https://kafka.apache.org/documentation/)
- [Kafka KRaft Mode](https://kafka.apache.org/documentation/#kraft)

## 🎯 로드맵

### 완료된 기능
- [x] Karate 기반 E2E 테스트 프레임워크
- [x] K3d 로컬 환경 자동화
- [x] GitHub Actions CI/CD
- [x] JWT 인증 통합
- [x] Istio Service Mesh 통합
- [x] 분산 추적 (Jaeger + OpenTelemetry)
- [x] 중앙 로그 수집 (Grafana Loki + Alloy)
- [x] 메트릭 모니터링 (Prometheus + Grafana)
- [x] 서비스 버전 제어 (서브모듈 독립적)
- [x] 외부 레포 트리거 지원

### 진행 중
- [ ] Kafka 이벤트 기반 테스트 시나리오
- [ ] Saga Choreography 패턴 테스트
- [ ] 각 MSA 서비스별 E2E 테스트 작성
  - [ ] User Service
  - [ ] Authorization Service
  - [ ] Store Service
  - [ ] Product Service
  - [ ] Order Service
  - [ ] Payment Service
  - [ ] Review Service
  - [ ] Recommendation Service

### 향후 계획
- [ ] 성능 테스트 (Gatling/K6 통합)
- [ ] Chaos Engineering (Chaos Mesh)
- [ ] 시각화 대시보드 (Allure Report)
- [ ] Multi-cluster 테스트 지원
- [ ] Contract Testing (Pact)
- [ ] Security Testing (OWASP ZAP)

## 🤝 기여

테스트 추가 또는 개선 시:
1. Feature 브랜치 생성
2. 테스트 작성 및 실행
3. PR 생성 (CI 자동 실행)
4. 리뷰 후 메인 브랜치 머지

## 📞 문의

- 테스트 프레임워크 관련: @your-username
- 인프라 관련: @sunhozy @tkddk0108
- CI/CD 관련: @eunjulee0603
