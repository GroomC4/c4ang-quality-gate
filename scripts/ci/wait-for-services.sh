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
    log_info "Pod Ready 상태 대기 중... (timeout: ${TIMEOUT}s)"

    export KUBECONFIG="${KUBECONFIG_FILE}"

    # kubectl wait를 사용하여 모든 Pod가 Ready 상태가 될 때까지 대기
    # condition=Ready는 컨테이너가 실제로 준비되었음을 보장
    log_info "kubectl wait으로 Pod Ready 상태 대기..."
    if kubectl wait --for=condition=Ready pods --all -n "${NAMESPACE}" --timeout="${TIMEOUT}s" 2>/dev/null; then
        local ready_count
        ready_count=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
        log_success "모든 Pod Ready 상태 (${ready_count}개)"
        kubectl get pods -n "${NAMESPACE}" 2>/dev/null || true
        return 0
    fi

    log_error "Pod Ready 대기 타임아웃"
    log_info "현재 Pod 상태:"
    kubectl get pods -n "${NAMESPACE}" -o wide 2>/dev/null || true
    log_info "Not Ready Pod 상세:"
    kubectl get pods -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{range .status.containerStatuses[*]}{.name}:{.ready}{" "}{end}{"\n"}{end}' 2>/dev/null || true
    return 1
}

# =============================================================================
# 서비스 엔드포인트 헬스체크
# =============================================================================

check_service_health() {
    log_info "서비스 헬스체크 수행 중..."

    export KUBECONFIG="${KUBECONFIG_FILE}"

    # 애플리케이션 서비스 확인
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

    # Istio Ingress Gateway 확인
    log_info "Istio Ingress Gateway 확인 중..."
    if kubectl get svc istio-ingressgateway -n istio-system &>/dev/null; then
        log_success "istio-ingressgateway 서비스 존재"
    else
        log_warn "istio-ingressgateway 서비스 없음"
        failed=$((failed + 1))
    fi

    # Gateway 리소스 확인
    if kubectl get gateway -n "${NAMESPACE}" &>/dev/null; then
        log_success "Gateway 리소스 존재"
        kubectl get gateway -n "${NAMESPACE}" 2>/dev/null || true
    else
        log_warn "Gateway 리소스 없음"
    fi

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
