#!/bin/bash

# c4ang-quality-gate 테스트 실행 스크립트
# E2E 테스트 실행 및 결과 리포트 생성

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 설정 변수
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${PROJECT_ROOT}/c4ang-infra"
K3D_KUBECONFIG="${INFRA_DIR}/k8s-dev-k3d/kubeconfig/config"
NAMESPACE="${NAMESPACE:-msa-quality}"

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 환경 확인
check_environment() {
    log_step "테스트 환경 확인 중..."

    # Kubeconfig 확인
    if [ -f "${K3D_KUBECONFIG}" ]; then
        export KUBECONFIG="${K3D_KUBECONFIG}"
        log_info "Kubeconfig 설정: ${K3D_KUBECONFIG}"
    else
        log_warn "Kubeconfig 파일을 찾을 수 없습니다: ${K3D_KUBECONFIG}"
        log_info "환경 변수 KUBECONFIG 사용"
    fi

    # 클러스터 연결 확인
    if kubectl cluster-info &> /dev/null; then
        log_info "클러스터 연결 성공"
    else
        log_error "클러스터에 연결할 수 없습니다."
        log_info "먼저 환경을 구축하세요: ./scripts/setup-test-env.sh"
        exit 1
    fi

    # 서비스 상태 확인
    log_info "서비스 상태 확인 중..."
    kubectl get pods -n "${NAMESPACE}" || {
        log_warn "네임스페이스 '${NAMESPACE}'에 Pod가 없습니다."
    }
}

# Gradle 빌드 확인
check_gradle() {
    log_step "Gradle 확인 중..."

    cd "${PROJECT_ROOT}"

    if [ ! -f "./gradlew" ]; then
        log_error "Gradle Wrapper를 찾을 수 없습니다."
        exit 1
    fi

    log_info "Gradle 준비 완료"
}

# 테스트 실행
run_tests() {
    log_step "E2E 테스트 실행 중..."

    cd "${PROJECT_ROOT}"

    # 테스트 환경 변수 설정
    export KARATE_ENV="${KARATE_ENV:-local}"
    export K8S_NAMESPACE="${NAMESPACE}"
    export KUBECONFIG_PATH="${K3D_KUBECONFIG}"

    log_info "테스트 환경: ${KARATE_ENV}"
    log_info "네임스페이스: ${K8S_NAMESPACE}"

    # Gradle 테스트 실행
    ./gradlew clean test \
        -Dkarate.env="${KARATE_ENV}" \
        -Dk8s.namespace="${K8S_NAMESPACE}" \
        -Dkubeconfig.path="${KUBECONFIG_PATH}" \
        --info || {
        log_error "테스트 실패"
        show_test_report
        exit 1
    }

    log_info "테스트 성공"
}

# 특정 테스트만 실행
run_specific_test() {
    local test_class=$1

    log_step "특정 테스트 실행 중: ${test_class}"

    cd "${PROJECT_ROOT}"

    export KARATE_ENV="${KARATE_ENV:-local}"
    export K8S_NAMESPACE="${NAMESPACE}"
    export KUBECONFIG_PATH="${K3D_KUBECONFIG}"

    ./gradlew clean test \
        --tests "${test_class}" \
        -Dkarate.env="${KARATE_ENV}" \
        -Dk8s.namespace="${K8S_NAMESPACE}" \
        -Dkubeconfig.path="${KUBECONFIG_PATH}" \
        --info || {
        log_error "테스트 실패"
        show_test_report
        exit 1
    }

    log_info "테스트 성공"
}

# 테스트 리포트 표시
show_test_report() {
    log_step "테스트 리포트 확인"

    local report_dir="${PROJECT_ROOT}/build/karate-reports"
    local html_report="${report_dir}/karate-summary.html"

    if [ -f "${html_report}" ]; then
        log_info "HTML 리포트: ${html_report}"
        log_info "브라우저로 열기: open ${html_report}"
    else
        log_warn "HTML 리포트를 찾을 수 없습니다."
    fi

    # JUnit 리포트
    local junit_report="${PROJECT_ROOT}/build/test-results/test"
    if [ -d "${junit_report}" ]; then
        log_info "JUnit 리포트: ${junit_report}"
    fi

    echo ""
    log_info "전체 리포트 디렉토리: ${PROJECT_ROOT}/build"
}

# 사용법 출력
usage() {
    echo "사용법: $0 [OPTIONS]"
    echo ""
    echo "옵션:"
    echo "  -t, --test <class>    특정 테스트 클래스 실행"
    echo "                        예: CustomerServiceTest, E2EScenarioTest, AllTestsRunner"
    echo "  -e, --env <env>       테스트 환경 설정 (local, dev, staging)"
    echo "  -h, --help            도움말 표시"
    echo ""
    echo "예제:"
    echo "  $0                                    # 모든 테스트 실행"
    echo "  $0 -t CustomerServiceTest             # Customer 서비스 테스트만 실행"
    echo "  $0 -t E2EScenarioTest                 # E2E 시나리오 테스트만 실행"
    echo "  $0 -e dev                             # dev 환경으로 테스트 실행"
    echo ""
}

# 메인 함수
main() {
    local test_class=""
    local test_env="${KARATE_ENV:-local}"

    # 인자 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--test)
                test_class="$2"
                shift 2
                ;;
            -e|--env)
                test_env="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                usage
                exit 1
                ;;
        esac
    done

    export KARATE_ENV="${test_env}"

    log_info "=== c4ang-quality-gate E2E 테스트 실행 ==="

    check_environment
    check_gradle

    if [ -n "${test_class}" ]; then
        run_specific_test "${test_class}"
    else
        run_tests
    fi

    show_test_report

    log_info "=== 테스트 완료 ==="
}

# 스크립트 실행
main "$@"
