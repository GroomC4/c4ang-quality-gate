#!/bin/bash
# =============================================================================
# CI용 K3d 환경 정리 스크립트
# =============================================================================
#
# GitHub Actions에서 E2E 테스트 완료 후 환경을 정리합니다.
#
# 사용법:
#   ./teardown-k3d-env.sh [--keep-external-services]
# =============================================================================

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 스크립트 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 설정
INFRA_REPO_PATH="${INFRA_REPO_PATH:-${PROJECT_ROOT}/../c4ang-infra}"
CLUSTER_NAME="${CLUSTER_NAME:-e2e-test-cluster}"
KUBECONFIG_FILE="${PROJECT_ROOT}/.kubeconfig"
KEEP_EXTERNAL_SERVICES="${KEEP_EXTERNAL_SERVICES:-false}"

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# K3d 클러스터 삭제
# =============================================================================

delete_cluster() {
    log_info "K3d 클러스터 삭제 중: ${CLUSTER_NAME}"

    if k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
        k3d cluster delete "${CLUSTER_NAME}"
        log_success "클러스터 삭제 완료"
    else
        log_info "클러스터가 존재하지 않습니다."
    fi

    # kubeconfig 삭제
    rm -f "${KUBECONFIG_FILE}"
}

# =============================================================================
# External Services 정리
# =============================================================================

stop_external_services() {
    if [ "$KEEP_EXTERNAL_SERVICES" == "true" ]; then
        log_info "External Services 유지됨"
        return 0
    fi

    log_info "External Services 중지 중..."

    local compose_dir="${INFRA_REPO_PATH}/external-services/docker"

    if [ -f "${compose_dir}/docker-compose.yaml" ]; then
        cd "${compose_dir}"
        docker compose down -v 2>/dev/null || docker-compose down -v || true
        cd "${PROJECT_ROOT}"
        log_success "External Services 중지 완료"
    else
        log_info "docker-compose.yaml을 찾을 수 없습니다."
    fi
}

# =============================================================================
# Istio 정리
# =============================================================================

cleanup_istio() {
    log_info "Istio 디렉토리 정리 중..."

    # 다운로드된 Istio 디렉토리 삭제
    rm -rf "${PROJECT_ROOT}/istio-"* 2>/dev/null || true
}

# =============================================================================
# Main
# =============================================================================

main() {
    # 옵션 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-external-services)
                KEEP_EXTERNAL_SERVICES="true"
                shift
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                exit 1
                ;;
        esac
    done

    log_info "E2E 테스트 환경 정리 시작"

    delete_cluster
    stop_external_services
    cleanup_istio

    log_success "환경 정리 완료"
}

main "$@"
