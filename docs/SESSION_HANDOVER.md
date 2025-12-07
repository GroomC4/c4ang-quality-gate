# CI E2E 테스트 세션 핸드오버 문서

**작성일**: 2025-12-07
**최종 업데이트**: 2025-12-07 19:22 KST
**현재 브랜치**: `feature/ci-e2e-workflow`
**마지막 커밋**: `719e9d5` - fix: AnalysisTemplate ownership 충돌 해결

---

## 1. 프로젝트 개요

GitHub Actions에서 k3d를 사용한 E2E 테스트 CI 파이프라인 구축 작업

### 목표
- 기본: k3d로 CI에서 E2E 테스트 실행
- 옵션: EKS Staging 환경 대상 테스트 지원

---

## 2. 완료된 작업

### 2.1 CI 스크립트 생성
| 파일 | 설명 |
|------|------|
| `scripts/ci/setup-k3d-env.sh` | K3d 환경 설정 (Docker Compose → K3d → Helm 배포) |
| `scripts/ci/teardown-k3d-env.sh` | K3d 환경 정리 |
| `scripts/ci/wait-for-services.sh` | 서비스 준비 대기 |
| `scripts/ci/setup-eks-env.sh` | EKS 환경 설정 |
| `config/ci/values-minimal.yaml` | CI용 최소화 Helm values |

### 2.2 GitHub Actions 워크플로우
- `.github/workflows/e2e-tests.yml` 생성
- k3d (기본) / eks-staging 환경 선택 가능
- workflow_dispatch로 수동 실행 지원

### 2.3 서브모듈 설정
- `c4ang-infra` 서브모듈 추가
- 브랜치: `feature/tunning-production-enviroment`

### 2.4 AWS OIDC 설정
- GitHub Actions용 IAM Role 생성 완료
- ECR 접근 권한 설정 완료
- Secret `AWS_ROLE_ARN` 등록 완료

---

## 3. 해결된 이슈들

| 이슈 | 원인 | 해결 |
|------|------|------|
| YAML syntax error (line 211) | 중첩 따옴표 | 전체 값을 큰따옴표로 감싸기 |
| 워크플로우 미트리거 | 브랜치 필터 | `'feature/ci-*'` 추가 |
| docker-compose not found | GitHub runner에 없음 | `docker compose` 플러그인 사용 |
| kafka-ui scale 오류 | profiles로 이미 제외됨 | `--scale kafka-ui=0` 옵션 제거 |
| Argo Rollouts CRD 404 | 잘못된 URL | kustomize 방식으로 변경 |
| redis-base dependency 누락 | helm dependency build 미실행 | 배포 전 `helm dependency build` 추가 |
| AnalysisTemplate 충돌 | 동일 이름 리소스 중복 생성 | 첫 배포 후 ownership annotation 제거 |

---

## 4. 현재 진행 중인 워크플로우

**Run ID**: `20002748140`
**상태**: 실행 중

### 마지막 확인된 진행 상황
```
✓ Set up job
✓ Checkout code with submodules
✓ Set up JDK 21
✓ Setup Docker
✓ Install k3d
✓ Install kubectl
✓ Install Helm
✓ Configure AWS credentials for ECR
✓ Setup K3d environment  <-- 통과!
* Create ECR pull secret  <-- 현재 진행 중
* Wait for K3d services
```

### 결과 확인 명령어
```bash
gh run view 20002748140 --repo GroomC4/c4ang-quality-gate
gh run view 20002748140 --repo GroomC4/c4ang-quality-gate --log-failed
```

---

## 5. 다음 세션에서 확인할 사항

### 5.1 워크플로우 결과 확인
```bash
gh run list --repo GroomC4/c4ang-quality-gate --limit 5
gh run view <RUN_ID> --repo GroomC4/c4ang-quality-gate --log-failed
```

### 5.2 예상되는 잠재적 이슈

1. **이미지 Pull 실패**
   - ECR에 이미지가 없을 수 있음
   - Public 이미지 사용 또는 mock 서비스 필요

2. **서비스 대기 타임아웃**
   - Pod가 Ready 상태가 되지 않을 수 있음
   - ImagePullBackOff 또는 CrashLoopBackOff 상태 확인

3. **포트 포워딩 문제**
   - 서비스가 올라오지 않으면 포트 포워딩 실패

4. **테스트 실행 실패**
   - Karate 테스트 설정 문제
   - 엔드포인트 접근 불가

---

## 6. 주요 파일 위치

```
c4ang-quality-gate/
├── .github/workflows/
│   └── e2e-tests.yml           # 메인 워크플로우
├── scripts/ci/
│   ├── setup-k3d-env.sh        # K3d 환경 설정
│   ├── teardown-k3d-env.sh     # 환경 정리
│   ├── wait-for-services.sh    # 서비스 대기
│   └── setup-eks-env.sh        # EKS 설정
├── config/ci/
│   └── values-minimal.yaml     # CI용 Helm values
├── c4ang-infra/                # 서브모듈 (인프라 설정)
│   └── external-services/docker/
│       └── docker-compose.yaml
├── docs/
│   ├── ci-architecture.md      # 아키텍처 문서
│   ├── TODO-ci-e2e-setup.md    # 작업 TODO 문서
│   └── SESSION_HANDOVER.md     # 이 문서
└── src/test/resources/
    └── karate-config.js        # 환경별 URL 설정
```

---

## 7. 커밋 히스토리 (이번 브랜치)

```
719e9d5 fix: AnalysisTemplate ownership 충돌 해결
68de698 fix: K3d E2E 환경 설정 스크립트 개선
94ad07d docs: 세션 핸드오버 문서 추가
61e7313 fix: docker compose --scale 옵션 제거
73dbbb3 fix: docker-compose 명령어를 docker compose로 수정
dd0648d ci: feature/ci-* 브랜치에서도 워크플로우 트리거 허용
4ed3f41 fix: K3d E2E 테스트 워크플로우 수정 및 인프라 서브모듈 브랜치 변경
e6dd0b9 refactor: c4ang-infra를 서브모듈로 추가
3b1d6e5 feat: K3d/EKS 통합 E2E 테스트 CI 파이프라인 구현
```

---

## 8. 이어서 작업하기

```bash
# 1. 저장소 이동
cd /Users/castle/Workspace/c4ang-quality-gate

# 2. 브랜치 확인
git branch -v

# 3. 최신 워크플로우 실행 결과 확인
gh run list --repo GroomC4/c4ang-quality-gate --limit 5

# 4. 실패한 경우 로그 확인
gh run view <RUN_ID> --repo GroomC4/c4ang-quality-gate --log-failed

# 5. Helm 배포 로그 확인
gh run view <RUN_ID> --log 2>&1 | grep -E "(Phase|배포|deploy|Error|helm)"
```

---

## 9. 주요 수정 내역

### setup-k3d-env.sh 주요 변경사항
1. **Argo Rollouts CRD 설치** (Phase 4)
   - kustomize 방식 사용: `kubectl apply -k https://github.com/argoproj/argo-rollouts/manifests/crds?ref=stable`

2. **Helm 배포** (Phase 6)
   - `helm dependency build` 추가 (redis-base 등 로컬 dependency 해결)
   - `--set redis.enabled=false` (ExternalName 서비스 사용)
   - AnalysisTemplate ownership annotation 제거 (충돌 방지)

---

## 10. 참고 사항

- **GitHub Actions Runner 스펙** (Public): 4 vCPU, 16GB RAM, 14GB Disk
- **K3d 예상 리소스**: ~3.1 vCPU, ~8.2GB RAM (여유 있음)
- **Karate 테스트 환경**: `k3d` 또는 `eks-staging`
- **포트 매핑**: 서비스 포트 80 → localhost 8081-8085
- **Argo Rollouts CRD 설치**: [공식 문서](https://argo-rollouts.readthedocs.io/en/stable/installation/)
