# TODO: CI E2E 테스트 환경 구축

> **관련 문서**: [CI 아키텍처 기획](./ci-architecture.md)

## 개요

GitHub Actions에서 K3d(기본) 및 EKS(옵션) 환경으로 E2E 테스트를 실행할 수 있는 CI 파이프라인 구축

---

## Phase 1: K3d 기반 E2E 테스트 (기본 환경)

### 1.1 CI용 인프라 스크립트 작성

- [ ] `scripts/ci/setup-k3d-env.sh` 작성
  - Docker Compose 시작 (외부 서비스)
  - K3d 클러스터 생성
  - Helm으로 서비스 직접 배포 (ArgoCD 제외)
  - 헬스체크 대기

- [ ] `scripts/ci/teardown-k3d-env.sh` 작성
  - K3d 클러스터 삭제
  - Docker Compose 정리

- [ ] `scripts/ci/wait-for-services.sh` 작성
  - 모든 Pod Ready 상태 확인
  - 서비스 엔드포인트 헬스체크

### 1.2 CI용 Helm values 작성

- [ ] `config/ci/values-minimal.yaml` 작성
  - Monitoring 비활성화 (Prometheus, Loki, Tempo, Grafana)
  - Istio 최소 설정
  - 리소스 requests/limits 최적화

### 1.3 GitHub Actions 워크플로우 작성

- [ ] `.github/workflows/e2e-tests.yml` 작성
  ```yaml
  on:
    pull_request:
      branches: [main, develop]
    push:
      branches: [main]
    workflow_dispatch:
      inputs:
        environment:
          type: choice
          options: [k3d, eks-staging]
  ```

- [ ] 워크플로우 단계 구현
  - Checkout
  - Setup Java 21
  - Setup Docker/K3d
  - K3d 환경 구축
  - Karate 테스트 실행
  - 결과 리포팅
  - 환경 정리

### 1.4 Karate 설정 수정

- [ ] `karate-config.js` 환경별 분기 추가
  - k3d: localhost (port-forward)
  - eks-staging: staging URL
  - eks-production: production URL

- [ ] `TestConfig.kt` 수정
  - CI 환경 감지 (GITHUB_ACTIONS 환경변수)
  - port-forward 자동 설정

### 1.5 테스트 및 검증

- [ ] 로컬에서 CI 스크립트 테스트
- [ ] GitHub Actions에서 K3d 환경 테스트
- [ ] 리소스 사용량 모니터링 (4 vCPU, 16GB 내)
- [ ] 전체 실행 시간 확인 (목표: 20분 이내)

---

## Phase 2: EKS 대상 E2E 테스트 (옵션)

### 2.1 AWS 인증 설정

- [ ] GitHub OIDC Provider 설정 (AWS)
- [ ] IAM Role 생성 (EKS 접근용)
- [ ] GitHub Secrets 설정
  - `AWS_ROLE_ARN`
  - `EKS_CLUSTER_NAME`
  - `EKS_REGION`

### 2.2 EKS 연결 스크립트 작성

- [ ] `scripts/ci/setup-eks-env.sh` 작성
  - AWS 자격증명 설정
  - kubeconfig 생성
  - 클러스터 연결 확인

### 2.3 네트워크 접근 설정

- [ ] 방법 선택:
  - [ ] Option A: Public Endpoint + Security Group (GitHub Actions IP 허용)
  - [ ] Option B: AWS VPN Client
  - [ ] Option C: Bastion Host + SSH Tunnel

- [ ] Istio Gateway 외부 접근 설정
  - ALB Public Endpoint
  - 테스트용 인증 토큰 관리

### 2.4 워크플로우 확장

- [ ] `.github/workflows/e2e-tests.yml` EKS 분기 추가
  ```yaml
  - name: Setup EKS Environment
    if: startsWith(inputs.environment, 'eks')
    uses: aws-actions/configure-aws-credentials@v4
  ```

### 2.5 테스트 데이터 관리

- [ ] EKS 테스트용 네임스페이스 분리 검토
- [ ] 테스트 데이터 초기화/정리 전략
- [ ] 운영 데이터 보호 방안

---

## Phase 3: 외부 레포지토리 트리거 연동

### 3.1 Repository Dispatch 설정

- [ ] `.github/workflows/trigger-e2e-tests.yml` 확인/수정
  - 외부 레포에서 전달받는 payload 처리
  - 특정 서비스 버전 설정
  - 결과 PR 코멘트

### 3.2 서비스 레포지토리 설정 가이드

- [ ] `docs/trigger-from-external-repo.md` 업데이트
  - GitHub Token 설정 방법
  - 트리거 워크플로우 예시
  - 결과 확인 방법

---

## Phase 4: 최적화 및 안정화

### 4.1 캐싱 적용

- [ ] Docker 이미지 캐싱 (actions/cache)
- [ ] Gradle 의존성 캐싱
- [ ] K3d 이미지 pre-pull

### 4.2 병렬화

- [ ] Docker Compose + K3d 생성 병렬화
- [ ] 테스트 suite 병렬 실행 검토

### 4.3 모니터링 및 알림

- [ ] 테스트 실패 시 Slack 알림
- [ ] 실행 시간 추이 모니터링
- [ ] 리소스 사용량 대시보드

---

## 완료 기준

### K3d 환경 (Phase 1)
- [ ] PR 생성 시 자동으로 K3d E2E 테스트 실행
- [ ] 모든 테스트 통과
- [ ] 실행 시간 20분 이내
- [ ] 테스트 결과 Artifact 업로드

### EKS 환경 (Phase 2)
- [ ] workflow_dispatch로 EKS 대상 테스트 가능
- [ ] 실행 시간 10분 이내
- [ ] 보안 자격증명 안전하게 관리

### 외부 트리거 (Phase 3)
- [ ] 서비스 레포에서 repository_dispatch로 E2E 트리거 가능
- [ ] 결과가 원본 PR에 코멘트로 전달

---

## 참고 명령어

```bash
# 로컬에서 CI 스크립트 테스트
./scripts/ci/setup-k3d-env.sh
./gradlew test
./scripts/ci/teardown-k3d-env.sh

# K3d 클러스터 상태 확인
k3d cluster list
kubectl get pods -A

# Docker 리소스 사용량 확인
docker stats

# GitHub Actions 로컬 테스트 (act)
act -j e2e-test --container-architecture linux/amd64
```

---

## 리스크 및 완화 방안

| 리스크 | 영향 | 완화 방안 |
|--------|------|-----------|
| Runner 메모리 부족 | 테스트 실패 | Monitoring 비활성화, 서비스 리소스 최적화 |
| 디스크 공간 부족 | 이미지 pull 실패 | 불필요한 이미지 정리, slim 이미지 사용 |
| 실행 시간 초과 | 타임아웃 실패 | 병렬화, 캐싱, 선택적 테스트 |
| ECR 인증 실패 | 이미지 pull 실패 | ecr-secret 자동 갱신 스크립트 |
| EKS 네트워크 차단 | 테스트 연결 불가 | Security Group 설정, VPN 검토 |

---

## 변경 이력

| 날짜 | 작성자 | 내용 |
|------|--------|------|
| 2024-12-07 | - | 초안 작성 |
