# 외부 레포에서 E2E 테스트 트리거하기

다른 서비스 레포지토리(예: customer-service, order-service)에서 c4ang-quality-gate의 E2E 테스트를 자동으로 트리거하는 방법입니다.

## 🚀 방법 1: GitHub Actions에서 repository_dispatch 사용

### 1. Personal Access Token (PAT) 생성

1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. "Generate new token" 클릭
3. 권한 선택:
   - `repo` (전체 체크)
   - `workflow` (체크)
4. 생성된 토큰을 복사

### 2. 서비스 레포에 Secret 추가

서비스 레포(예: customer-service) → Settings → Secrets and variables → Actions

- Name: `E2E_TRIGGER_TOKEN`
- Value: 위에서 생성한 PAT

### 3. 서비스 레포에 Workflow 추가

`customer-service/.github/workflows/trigger-e2e-after-build.yml`:

```yaml
name: Trigger E2E Tests After Build

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main

jobs:
  build-and-trigger-e2e:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Build and test
        run: ./gradlew build

      - name: Build Docker image
        id: docker_build
        run: |
          # 이미지 태그 생성 (브랜치명-커밋SHA)
          IMAGE_TAG="${GITHUB_REF_NAME}-${GITHUB_SHA::7}"
          echo "image_tag=${IMAGE_TAG}" >> $GITHUB_OUTPUT

          # Docker 이미지 빌드
          docker build -t c4ang/customer-service:${IMAGE_TAG} .

          # Docker registry에 푸시 (실제 환경에서)
          # docker push c4ang/customer-service:${IMAGE_TAG}

      - name: Trigger E2E tests in quality-gate repo
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.E2E_TRIGGER_TOKEN }}
          script: |
            await github.rest.repos.createDispatchEvent({
              owner: 'GroomC4',
              repo: 'c4ang-quality-gate',
              event_type: 'trigger-e2e-test',
              client_payload: {
                service_name: 'customer-service',
                image_tag: '${{ steps.docker_build.outputs.image_tag }}',
                test_suite: 'CustomerServiceTest',
                environment: 'local',
                pr_number: context.issue.number || null,
                repo_name: context.repo.repo,
                triggered_by: context.actor,
                commit_sha: context.sha
              }
            });

      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `🧪 E2E 테스트가 트리거되었습니다!

              - **이미지 태그**: \`${{ steps.docker_build.outputs.image_tag }}\`
              - **테스트 상태**: [c4ang-quality-gate Actions 확인](https://github.com/GroomC4/c4ang-quality-gate/actions)

              테스트 결과는 완료 후 이 PR에 자동으로 코멘트됩니다.`
            })
```

### 4. 특정 조건에서만 트리거 (선택적)

특정 라벨이 있거나, 특정 파일이 변경된 경우에만 E2E 테스트 실행:

```yaml
name: Conditional E2E Trigger

on:
  pull_request:
    types: [labeled, synchronize]

jobs:
  trigger-e2e:
    # 'e2e-test' 라벨이 있을 때만 실행
    if: contains(github.event.pull_request.labels.*.name, 'e2e-test')
    runs-on: ubuntu-latest

    steps:
      # ... (위와 동일)
```

---

## 🔧 방법 2: curl로 직접 트리거

로컬 또는 다른 CI 도구에서:

```bash
#!/bin/bash

GITHUB_TOKEN="your-pat-token"
SERVICE_NAME="customer-service"
IMAGE_TAG="v1.0.0"

curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  https://api.github.com/repos/GroomC4/c4ang-quality-gate/dispatches \
  -d "{
    \"event_type\": \"trigger-e2e-test\",
    \"client_payload\": {
      \"service_name\": \"${SERVICE_NAME}\",
      \"image_tag\": \"${IMAGE_TAG}\",
      \"test_suite\": \"CustomerServiceTest\",
      \"environment\": \"local\"
    }
  }"
```

---

## 🎯 방법 3: GitHub UI에서 수동 실행

1. c4ang-quality-gate 레포 → Actions 탭
2. "Trigger E2E Tests (From External Repo)" 선택
3. "Run workflow" 클릭
4. 파라미터 입력:
   - Service name: `customer-service`
   - Image tag: `v1.0.0`
   - Test suite: `CustomerServiceTest`
   - Environment: `local`
5. "Run workflow" 클릭

---

## 📊 Payload 파라미터

| 파라미터 | 설명 | 필수 | 기본값 |
|---------|------|------|--------|
| `service_name` | 테스트할 서비스 이름 | ✅ | - |
| `image_tag` | Docker 이미지 태그 | ✅ | `latest` |
| `test_suite` | 실행할 테스트 스위트 | ❌ | `all` |
| `environment` | 테스트 환경 | ❌ | `local` |
| `pr_number` | PR 번호 (결과 코멘트용) | ❌ | - |
| `repo_name` | 트리거한 레포 이름 | ❌ | - |
| `callback_url` | 완료 후 콜백 URL | ❌ | - |

---

## 🔍 테스트 결과 확인

### 1. GitHub Actions UI
- https://github.com/GroomC4/c4ang-quality-gate/actions

### 2. PR 코멘트
- PR이 있는 경우, 테스트 결과가 자동으로 코멘트됨

### 3. Artifacts
- Actions 실행 페이지 → Artifacts → `test-reports-{service}-{tag}` 다운로드

---

## 🛠️ 고급 시나리오

### 여러 서비스 동시 테스트

```yaml
- name: Trigger E2E for multiple services
  run: |
    for service in customer-service order-service payment-service; do
      curl -X POST \
        -H "Authorization: Bearer ${{ secrets.E2E_TRIGGER_TOKEN }}" \
        https://api.github.com/repos/GroomC4/c4ang-quality-gate/dispatches \
        -d "{
          \"event_type\": \"trigger-e2e-test\",
          \"client_payload\": {
            \"service_name\": \"${service}\",
            \"image_tag\": \"${IMAGE_TAG}\",
            \"test_suite\": \"all\"
          }
        }"
    done
```

### 테스트 결과 대기 및 실패 시 롤백

```yaml
- name: Wait for E2E test results
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.E2E_TRIGGER_TOKEN }}
    script: |
      // E2E 테스트 워크플로우 상태 모니터링 로직
      // 완료까지 대기 후 결과 확인
```

---

## 📝 예제: customer-service 전체 워크플로우

```yaml
name: Build, Push, and E2E Test

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Run unit tests
        run: ./gradlew test

      - name: Build Docker image
        id: build
        run: |
          IMAGE_TAG="${GITHUB_REF_NAME}-$(git rev-parse --short HEAD)"
          echo "tag=${IMAGE_TAG}" >> $GITHUB_OUTPUT
          docker build -t c4ang/customer-service:${IMAGE_TAG} .

      - name: Push to registry
        run: |
          # Docker Hub 또는 Private Registry에 푸시
          # docker push c4ang/customer-service:${{ steps.build.outputs.tag }}

      - name: Trigger E2E tests
        uses: peter-evans/repository-dispatch@v2
        with:
          token: ${{ secrets.E2E_TRIGGER_TOKEN }}
          repository: GroomC4/c4ang-quality-gate
          event-type: trigger-e2e-test
          client-payload: |
            {
              "service_name": "customer-service",
              "image_tag": "${{ steps.build.outputs.tag }}",
              "test_suite": "CustomerServiceTest",
              "environment": "local",
              "pr_number": "${{ github.event.number }}",
              "repo_name": "${{ github.repository }}"
            }
```

---

## 🔐 보안 고려사항

1. **PAT 권한 최소화**: `repo`, `workflow`만 부여
2. **Secret 관리**: GitHub Secrets에 안전하게 저장
3. **토큰 만료**: 주기적으로 토큰 갱신
4. **Payload 검증**: 신뢰할 수 없는 입력 검증

---

## 🐛 트러블슈팅

### 트리거가 작동하지 않는 경우

1. **PAT 권한 확인**
   ```bash
   # PAT가 올바른지 테스트
   curl -H "Authorization: Bearer ${TOKEN}" https://api.github.com/user
   ```

2. **Workflow 활성화 확인**
   - c4ang-quality-gate 레포 → Actions → Workflow 활성화

3. **Payload 형식 확인**
   - `event_type`이 정확히 `trigger-e2e-test`인지 확인
   - JSON 형식이 올바른지 확인

4. **로그 확인**
   - Actions 탭에서 실행 로그 확인
