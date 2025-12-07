#!/bin/bash
# =============================================================================
# 서비스 준비 대기 스크립트
# =============================================================================
#
# 모든 서비스가 준비될 때까지 대기하고 헬스체크를 수행합니다.
#
# 사용법:
#   ./wait-for-services.sh [--timeout 300]
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
KUBECONFIG_FILE="${PROJECT_ROOT}/.kubeconfig"
NAMESPACE="${NAMESPACE:-ecommerce}"
TIMEOUT="${TIMEOUT:-300}"

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Pod 준비 대기
# =============================================================================

wait_for_pods() {
    log_info "Pod 준비 대기 중... (timeout: ${TIMEOUT}s)"

    export KUBECONFIG="${KUBECONFIG_FILE}"

    local waited=0

    while [ $waited -lt $TIMEOUT ]; do
        local ready_pods
        ready_pods=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -c "Running" || echo "0")

        local total_pods
        total_pods=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l | tr -d ' ')

        if [ "$total_pods" -gt 0 ] && [ "$ready_pods" -eq "$total_pods" ]; then
            log_success "모든 Pod 실행 중 (${ready_pods}/${total_pods})"
            return 0
        fi

        sleep 10
        waited=$((waited + 10))
        log_info "대기 중... (${waited}s/${TIMEOUT}s, ${ready_pods}/${total_pods} running)"
    done

    log_error "Pod 준비 타임아웃"
    kubectl get pods -n "${NAMESPACE}"
    return 1
}

# =============================================================================
# 서비스 엔드포인트 헬스체크
# =============================================================================

check_service_health() {
    log_info "서비스 헬스체크 수행 중..."

    export KUBECONFIG="${KUBECONFIG_FILE}"

    local services=("customer-api" "order-api" "product-api" "store-api" "payment-api" "saga-tracker-api")
    local failed=0

    for service in "${services[@]}"; do
        # 서비스 존재 확인
        if kubectl get svc "${service}" -n "${NAMESPACE}" &>/dev/null; then
            log_success "${service} 서비스 존재"
        else
            log_warn "${service} 서비스 없음"
            failed=$((failed + 1))
        fi
    done

    if [ $failed -gt 0 ]; then
        log_warn "${failed}개 서비스 누락"
        return 1
    fi

    log_success "모든 서비스 헬스체크 통과"
    return 0
}

# =============================================================================
# Main
# =============================================================================

main() {
    # 옵션 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                exit 1
                ;;
        esac
    done

    if [ ! -f "${KUBECONFIG_FILE}" ]; then
        log_error "KUBECONFIG 파일을 찾을 수 없습니다: ${KUBECONFIG_FILE}"
        exit 1
    fi

    wait_for_pods
    check_service_health

    log_success "서비스 준비 완료"
}

main "$@"
