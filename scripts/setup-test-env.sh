#!/bin/bash

# c4ang-quality-gate 테스트 환경 구축 스크립트
# K3d 클러스터 생성 및 MSA 서비스 배포

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
K3D_SCRIPT_DIR="${INFRA_DIR}/k8s-dev-k3d"
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

# 서브모듈 확인 및 업데이트
check_submodule() {
    log_step "서브모듈 확인 중..."

    if [ ! -d "${INFRA_DIR}" ] || [ -z "$(ls -A "${INFRA_DIR}")" ]; then
        log_warn "인프라 서브모듈이 초기화되지 않았습니다."
        log_info "서브모듈 초기화 중..."
        cd "${PROJECT_ROOT}"
        git submodule update --init --recursive
    fi

    if [ ! -d "${K3D_SCRIPT_DIR}" ]; then
        log_error "인프라 디렉토리를 찾을 수 없습니다: ${K3D_SCRIPT_DIR}"
        exit 1
    fi

    log_info "서브모듈 확인 완료"
}

# K3d 클러스터 설치
install_k3d_cluster() {
    log_step "K3d 클러스터 설치 중..."

    if [ ! -f "${K3D_SCRIPT_DIR}/install-k3s.sh" ]; then
        log_error "K3d 설치 스크립트를 찾을 수 없습니다: ${K3D_SCRIPT_DIR}/install-k3s.sh"
        exit 1
    fi

    cd "${K3D_SCRIPT_DIR}"
    bash install-k3s.sh

    log_info "K3d 클러스터 설치 완료"
}

# 인프라 및 서비스 배포
deploy_services() {
    log_step "인프라 및 서비스 배포 중..."

    if [ ! -f "${K3D_SCRIPT_DIR}/scripts/start-environment.sh" ]; then
        log_error "환경 시작 스크립트를 찾을 수 없습니다: ${K3D_SCRIPT_DIR}/scripts/start-environment.sh"
        exit 1
    fi

    cd "${K3D_SCRIPT_DIR}/scripts"
    bash start-environment.sh

    log_info "인프라 배포 완료"
}

# 서비스 이미지 태그 로드
load_service_versions() {
    local versions_file="${PROJECT_ROOT}/config/service-versions.yaml"

    if [ -f "${versions_file}" ]; then
        log_info "서비스 버전 설정 로드: ${versions_file}"
        # YAML 파싱은 yq 사용 (없으면 환경변수로 대체)
        if command -v yq &> /dev/null; then
            CUSTOMER_SERVICE_TAG=$(yq eval '.services.customer-service.image.tag' "${versions_file}" 2>/dev/null || echo "latest")
        else
            CUSTOMER_SERVICE_TAG="${CUSTOMER_SERVICE_TAG:-latest}"
            log_warn "yq not found. Using default or env var: ${CUSTOMER_SERVICE_TAG}"
        fi
    else
        CUSTOMER_SERVICE_TAG="${CUSTOMER_SERVICE_TAG:-latest}"
        log_info "기본 이미지 태그 사용: ${CUSTOMER_SERVICE_TAG}"
    fi
}

# MSA 서비스 배포 (customer-service 등)
deploy_msa_services() {
    log_step "MSA 서비스 배포 중..."

    local kubeconfig_file="${K3D_SCRIPT_DIR}/kubeconfig/config"
    export KUBECONFIG="${kubeconfig_file}"

    # 서비스 버전 로드
    load_service_versions

    # customer-service 배포 (예시)
    local customer_chart="${INFRA_DIR}/helm/services/customer-service"
    local test_overrides="${PROJECT_ROOT}/config/test-overrides.yaml"

    if [ -d "${customer_chart}" ]; then
        log_info "Customer Service 배포 중 (이미지 태그: ${CUSTOMER_SERVICE_TAG})..."

        # Helm dependencies 빌드 (필요시)
        if [ -f "${customer_chart}/Chart.yaml" ]; then
            helm dependency build "${customer_chart}" 2>/dev/null || true
        fi

        # Customer Service 배포 (이미지 태그 오버라이드)
        local helm_args=(
            --namespace "${NAMESPACE}"
            --create-namespace
            --wait
            --timeout 300s
        )

        # test-overrides.yaml이 있으면 사용
        if [ -f "${test_overrides}" ]; then
            helm_args+=(--values "${test_overrides}")
        fi

        # 이미지 태그 오버라이드 (환경변수 또는 service-versions.yaml)
        helm_args+=(--set "image.tag=${CUSTOMER_SERVICE_TAG}")

        helm upgrade --install customer-service "${customer_chart}" "${helm_args[@]}" || {
            log_warn "Customer Service 배포 실패 또는 타임아웃"
            log_info "수동으로 확인하세요: kubectl get pods -n ${NAMESPACE}"
        }

        log_info "Customer Service 배포 완료 (태그: ${CUSTOMER_SERVICE_TAG})"
    else
        log_warn "Customer Service 차트를 찾을 수 없습니다: ${customer_chart}"
        log_info "인프라만 배포되었습니다."
    fi

    # 다른 서비스들도 여기에 추가
    # TODO: order-service, payment-service 등이 추가되면 배포 로직 추가
}

# 서비스 상태 확인
verify_deployment() {
    log_step "배포 상태 확인 중..."

    local kubeconfig_file="${K3D_SCRIPT_DIR}/kubeconfig/config"
    export KUBECONFIG="${kubeconfig_file}"

    echo ""
    echo "=== Pod 상태 ==="
    kubectl get pods -n "${NAMESPACE}" || true

    echo ""
    echo "=== Service 목록 ==="
    kubectl get svc -n "${NAMESPACE}" || true

    echo ""
    log_info "배포 확인 완료"
}

# 테스트 준비 상태 출력
show_test_instructions() {
    log_step "테스트 준비 완료"

    local kubeconfig_file="${K3D_SCRIPT_DIR}/kubeconfig/config"

    echo ""
    echo "========================================"
    echo "테스트 환경이 준비되었습니다!"
    echo "========================================"
    echo ""
    echo "1. Kubeconfig 설정:"
    echo "   export KUBECONFIG=${kubeconfig_file}"
    echo ""
    echo "2. 클러스터 확인:"
    echo "   kubectl get pods -n ${NAMESPACE}"
    echo ""
    echo "3. E2E 테스트 실행:"
    echo "   cd ${PROJECT_ROOT}"
    echo "   ./scripts/run-tests.sh"
    echo ""
    echo "또는 Gradle로 직접 실행:"
    echo "   ./gradlew test"
    echo ""
    echo "4. 환경 정리:"
    echo "   ./scripts/teardown-test-env.sh"
    echo ""
    echo "========================================"
}

# 메인 함수
main() {
    log_info "=== c4ang-quality-gate 테스트 환경 구축 시작 ==="

    check_submodule
    install_k3d_cluster
    deploy_services
    deploy_msa_services
    verify_deployment
    show_test_instructions

    log_info "=== 테스트 환경 구축 완료 ==="
}

# 스크립트 실행
main "$@"
