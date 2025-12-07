# E2E 테스트 CI 아키텍처 기획

## 개요

GitHub Actions에서 Karate 기반 E2E 테스트를 실행하기 위한 CI 아키텍처입니다.
**기본값으로 K3d 환경**을 사용하고, **옵션으로 EKS 환경**을 선택할 수 있습니다.

---

## 1. 요구사항

### 1.1 기능 요구사항

- PR/Push 이벤트 시 자동으로 E2E 테스트 실행
- 테스트 환경 선택 가능 (k3d/eks)
- 특정 서비스 버전으로 테스트 가능
- 테스트 결과 리포팅 (PR 코멘트, Artifacts)
- 외부 서비스 레포지토리에서 트리거 가능

### 1.2 비기능 요구사항

- GitHub Actions Public Runner 리소스 내에서 실행 (4 vCPU, 16GB RAM, 14GB Disk)
- 전체 실행 시간 20분 이내
- 실패 시 명확한 원인 파악 가능

---

## 2. 환경별 특성 비교

| 항목 | K3d (기본) | EKS (옵션) |
|------|------------|------------|
| **실행 위치** | GitHub Actions Runner | AWS EKS 클러스터 |
| **인프라 구축** | 매 실행마다 생성/삭제 | 기존 인프라 사용 |
| **데이터 격리** | 완전 격리 (매번 초기화) | 테스트용 네임스페이스 |
| **실행 시간** | ~15-20분 (인프라 구축 포함) | ~5분 (테스트만) |
| **비용** | 무료 (Public Repo) | EKS 운영 비용 |
| **외부 의존성** | 없음 | AWS 자격증명, 네트워크 |
| **용도** | PR 검증, 개발 테스트 | 스테이징/운영 환경 검증 |

---

## 3. 아키텍처 설계

### 3.1 K3d 기반 아키텍처 (기본)

```
┌─────────────────────────────────────────────────────────────────────┐
│  GitHub Actions Runner (ubuntu-latest)                              │
│  4 vCPU, 16GB RAM, 14GB Disk                                        │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Docker Compose (External Services)                          │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐│   │
│  │  │ Postgres │ │  Redis   │ │  Kafka   │ │ Schema Registry  ││   │
│  │  │  × 7     │ │  × 2     │ │ (KRaft)  │ │                  ││   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘│   │
│  │  ~1.85 GB Memory                                             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  K3d Cluster                                                 │   │
│  │  ┌─────────────────────────────────────────────────────────┐│   │
│  │  │  MSA Services (6개)                                     ││   │
│  │  │  customer / order / product / store / payment / saga    ││   │
│  │  │  각 512Mi Memory, 100m CPU                              ││   │
│  │  └─────────────────────────────────────────────────────────┘│   │
│  │  ┌─────────────────────────────────────────────────────────┐│   │
│  │  │  Istio (Gateway, Sidecar)                               ││   │
│  │  └─────────────────────────────────────────────────────────┘│   │
│  │  ~5.8 GB Memory                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Karate E2E Tests (JVM)                                      │   │
│  │  ~512 MB Memory                                              │   │
│  │  port-forward → K3d Services                                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Total: ~3.1 vCPU, ~8.2 GB Memory                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 EKS 대상 아키텍처 (옵션)

```
┌────────────────────────────────────────┐
│  GitHub Actions Runner                 │
│  ┌──────────────────────────────────┐ │
│  │  Karate E2E Tests (JVM)          │ │
│  │  ~512 MB Memory                  │ │
│  └──────────────┬───────────────────┘ │
└─────────────────┼──────────────────────┘
                  │ HTTPS (Public Endpoint)
                  │ or VPN/Direct Connect
                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  AWS EKS Cluster                                                   │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  Istio Ingress Gateway (ALB)                                  │ │
│  │  api.ecommerce.com / api-staging.ecommerce.com               │ │
│  └──────────────────────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  MSA Services (customer, order, product, store, payment...)  │ │
│  └──────────────────────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  RDS / ElastiCache / MSK                                     │ │
│  └──────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

---

## 4. 워크플로우 설계

### 4.1 통합 워크플로우 구조

```yaml
# .github/workflows/e2e-tests.yml
name: E2E Tests

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Test environment'
        required: true
        default: 'k3d'
        type: choice
        options:
          - k3d
          - eks-staging
          - eks-production
      service_versions:
        description: 'Service versions (JSON format)'
        required: false
        type: string

jobs:
  e2e-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # 환경에 따라 분기
      - name: Setup K3d Environment
        if: inputs.environment == 'k3d' || inputs.environment == ''
        run: ./scripts/setup-k3d-env.sh

      - name: Setup EKS Environment
        if: startsWith(inputs.environment, 'eks')
        run: ./scripts/setup-eks-env.sh

      - name: Run Karate Tests
        run: ./scripts/run-tests.sh

      - name: Upload Results
        uses: actions/upload-artifact@v4
```

### 4.2 실행 시나리오

#### 시나리오 1: PR 생성/업데이트 (기본 - K3d)
```
PR 생성 → K3d 환경 구축 → E2E 테스트 실행 → 결과 리포트 → 환경 정리
```

#### 시나리오 2: 수동 실행 (EKS 선택)
```
workflow_dispatch (eks-staging) → EKS 연결 → E2E 테스트 실행 → 결과 리포트
```

#### 시나리오 3: 외부 서비스 레포에서 트리거
```
user-service PR → repository_dispatch → 특정 버전 테스트 → 결과 코멘트
```

---

## 5. 리소스 최적화 전략

### 5.1 K3d 환경 경량화

기존 인프라 설정에서 CI 전용으로 최적화:

| 컴포넌트 | 기존 설정 | CI 최적화 | 비고 |
|----------|-----------|-----------|------|
| Monitoring | 활성화 | **비활성화** | Prometheus, Loki, Tempo 제외 |
| ArgoCD | 활성화 | **비활성화** | Helm 직접 설치 |
| 서비스 replicas | 1 | 1 | 유지 |
| PostgreSQL | 7개 | 7개 | 유지 (필수) |
| Kafka UI | 선택적 | **비활성화** | 불필요 |

**예상 리소스 절감:**
- Memory: ~8.2 GB → ~5.5 GB
- Disk: 이미지 크기 ~30% 감소
- 시작 시간: ~5분 단축

### 5.2 병렬 처리 최적화

```yaml
jobs:
  setup:
    # Docker Compose + K3d 클러스터 생성 병렬화
    steps:
      - name: Start External Services
        run: docker-compose up -d &
      - name: Create K3d Cluster
        run: k3d cluster create ...
      - name: Wait for Services
        run: ./scripts/wait-for-services.sh
```

---

## 6. 시크릿 및 설정 관리

### 6.1 K3d 환경
```yaml
# 시크릿 불필요 - 모든 자격증명이 로컬
env:
  POSTGRES_PASSWORD: postgres
  REDIS_PASSWORD: ""
```

### 6.2 EKS 환경
```yaml
# GitHub Secrets 필요
secrets:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  EKS_CLUSTER_NAME: ${{ secrets.EKS_CLUSTER_NAME }}
  # 또는 OIDC 기반 인증 (권장)
  AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

### 6.3 Karate 설정 분기

```javascript
// karate-config.js
function fn() {
  var env = karate.env || 'k3d';

  var config = {
    baseUrl: 'http://localhost:8080',
    authUrl: 'http://localhost:8081'
  };

  if (env == 'k3d') {
    // port-forward 사용
    config.baseUrl = 'http://localhost:8080';
  } else if (env == 'eks-staging') {
    config.baseUrl = 'https://api-staging.ecommerce.com';
  } else if (env == 'eks-production') {
    config.baseUrl = 'https://api.ecommerce.com';
  }

  return config;
}
```

---

## 7. 에러 핸들링 및 디버깅

### 7.1 K3d 환경 실패 시

```yaml
- name: Debug K3d Failure
  if: failure()
  run: |
    echo "=== Docker Compose Logs ==="
    docker-compose logs --tail=100
    echo "=== K3d Cluster Info ==="
    k3d cluster list
    kubectl get pods -A
    kubectl describe pods -n ecommerce
```

### 7.2 테스트 실패 시 Artifact 수집

```yaml
- name: Upload Test Results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: karate-reports
    path: |
      target/karate-reports/
      target/surefire-reports/
```

---

## 8. 확장 가능성

### 8.1 향후 개선 사항

1. **캐싱 적용**: Docker 이미지 레이어 캐싱으로 빌드 시간 단축
2. **병렬 테스트**: 서비스별 테스트를 matrix로 병렬 실행
3. **선택적 테스트**: 변경된 서비스만 테스트 (path filter)
4. **성능 테스트 통합**: K6, Gatling 연동

### 8.2 Self-hosted Runner 전환 시

리소스 제한을 벗어나야 할 경우:
- AWS EC2 기반 Self-hosted Runner
- 더 큰 리소스 (8 vCPU, 32GB RAM)
- 영구 캐시 활용 가능

---

## 참고 문서

- [GitHub Actions Runner 스펙](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [K3d 공식 문서](https://k3d.io/)
- [Karate 공식 문서](https://github.com/karatelabs/karate)
- [시스템 아키텍처](./system-architecture.md)
- [E2E 테스트 계획](./e2e-test-plan.md)
