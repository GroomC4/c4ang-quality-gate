#!/bin/bash
# =============================================================================
# CI용 K3d 환경 설정 스크립트
# =============================================================================
#
# GitHub Actions에서 E2E 테스트를 위한 경량화된 K3d 환경을 구축합니다.
# - ArgoCD 제외 (Helm 직접 배포)
# - Monitoring 제외 (Prometheus, Loki, Tempo, Grafana)
# - 최소 리소스 설정
#
# 사용법:
#   ./setup-k3d-env.sh [--skip-external-services]
#
# 환경변수:
#   INFRA_REPO_PATH     - c4ang-infra 레포지토리 경로 (기본: ../c4ang-infra)
#   CLUSTER_NAME        - K3d 클러스터 이름 (기본: e2e-test-cluster)
#   NAMESPACE           - 서비스 배포 네임스페이스 (기본: ecommerce)
#   SKIP_ISTIO          - Istio 설치 스킵 (기본: false)
# =============================================================================

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 스크립트 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 설정
# 서브모듈로 포함된 c4ang-infra 사용 (기본값)
INFRA_REPO_PATH="${INFRA_REPO_PATH:-${PROJECT_ROOT}/c4ang-infra}"
CLUSTER_NAME="${CLUSTER_NAME:-e2e-test-cluster}"
NAMESPACE="${NAMESPACE:-ecommerce}"
KUBECONFIG_FILE="${PROJECT_ROOT}/.kubeconfig"
SKIP_EXTERNAL_SERVICES="${SKIP_EXTERNAL_SERVICES:-false}"
SKIP_ISTIO="${SKIP_ISTIO:-false}"

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${CYAN}▶ $1${NC}"; }

# 에러 핸들링
trap 'log_error "스크립트 실행 중 오류 발생 (line: $LINENO)"; exit 1' ERR

# =============================================================================
# Phase 1: 사전 검사
# =============================================================================

check_prerequisites() {
    log_step "Phase 1: 사전 요구사항 확인"

    local missing=()

    command -v docker &>/dev/null || missing+=("docker")
    command -v k3d &>/dev/null || missing+=("k3d")
    command -v kubectl &>/dev/null || missing+=("kubectl")
    command -v helm &>/dev/null || missing+=("helm")

    if [ "$SKIP_EXTERNAL_SERVICES" != "true" ]; then
        command -v docker-compose &>/dev/null || command -v docker &>/dev/null || missing+=("docker-compose")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "다음 도구가 필요합니다: ${missing[*]}"
        exit 1
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker 데몬이 실행 중이지 않습니다."
        exit 1
    fi

    # 인프라 레포 확인
    if [ ! -d "${INFRA_REPO_PATH}" ]; then
        log_error "인프라 레포지토리를 찾을 수 없습니다: ${INFRA_REPO_PATH}"
        log_info "INFRA_REPO_PATH 환경변수를 설정하거나 git submodule을 초기화하세요."
        exit 1
    fi

    log_success "사전 요구사항 확인 완료"
}

# =============================================================================
# Phase 2: External Services (Docker Compose)
# =============================================================================

start_external_services() {
    if [ "$SKIP_EXTERNAL_SERVICES" == "true" ]; then
        log_info "External Services 스킵됨"
        return 0
    fi

    log_step "Phase 2: External Services 시작 (PostgreSQL, Redis, Kafka)"

    local compose_dir="${INFRA_REPO_PATH}/external-services/docker"

    if [ ! -f "${compose_dir}/docker-compose.yaml" ]; then
        log_error "docker-compose.yaml을 찾을 수 없습니다: ${compose_dir}"
        exit 1
    fi

    cd "${compose_dir}"

    # Kafka UI는 profiles: [ui]로 설정되어 있어 기본 실행시 제외됨
    log_info "Docker Compose 서비스 시작 중..."
    docker compose up -d

    # 헬스체크 대기 (CI 환경이므로 짧게)
    log_info "서비스 헬스체크 대기 중..."
    local max_wait=90
    local waited=0

    while [ $waited -lt $max_wait ]; do
        # PostgreSQL 연결 확인 (가장 중요)
        if docker exec customer-db pg_isready -U postgres &>/dev/null && \
           docker exec kafka nc -z localhost 9092 &>/dev/null; then
            log_success "핵심 서비스 준비 완료"
            break
        fi

        sleep 5
        waited=$((waited + 5))
        log_info "대기 중... (${waited}s/${max_wait}s)"
    done

    if [ $waited -ge $max_wait ]; then
        log_warn "일부 서비스가 완전히 준비되지 않았을 수 있습니다."
        docker compose ps 2>/dev/null || docker-compose ps
    fi

    cd "${PROJECT_ROOT}"
}

# =============================================================================
# Phase 3: K3d Cluster 생성
# =============================================================================

create_cluster() {
    log_step "Phase 3: K3d 클러스터 생성"

    # 기존 클러스터 삭제
    if k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
        log_info "기존 클러스터 삭제 중..."
        k3d cluster delete "${CLUSTER_NAME}" || true
    fi

    log_info "K3d 클러스터 생성 중: ${CLUSTER_NAME}"

    k3d cluster create "${CLUSTER_NAME}" \
        --api-port 6443 \
        --port "8080:80@loadbalancer" \
        --port "8443:443@loadbalancer" \
        --k3s-arg "--disable=traefik@server:0" \
        --wait \
        --timeout 180s

    # kubeconfig 저장
    k3d kubeconfig write "${CLUSTER_NAME}" --output "${KUBECONFIG_FILE}"
    export KUBECONFIG="${KUBECONFIG_FILE}"

    # 클러스터 연결 확인
    local retry=0
    while [ $retry -lt 10 ]; do
        if kubectl cluster-info &>/dev/null; then
            log_success "클러스터 연결 성공"
            break
        fi
        retry=$((retry + 1))
        sleep 2
    done

    if [ $retry -ge 10 ]; then
        log_error "클러스터에 연결할 수 없습니다."
        exit 1
    fi

    # 네임스페이스 생성
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    log_success "네임스페이스 생성: ${NAMESPACE}"
}

# =============================================================================
# Phase 4: Argo Rollouts CRD 설치 (Helm 차트 의존성)
# =============================================================================

install_argo_rollouts_crd() {
    log_step "Phase 4: Argo Rollouts CRD 설치"

    export KUBECONFIG="${KUBECONFIG_FILE}"

    # Argo Rollouts CRD 설치 (kustomize 사용 - 공식 권장 방법)
    log_info "Argo Rollouts CRD 설치 중..."
    kubectl apply -k https://github.com/argoproj/argo-rollouts/manifests/crds?ref=stable || {
        log_warn "kustomize 방식 실패, 전체 설치 시도..."
        kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml || true
    }

    log_success "Argo Rollouts CRD 설치 완료"
}

# =============================================================================
# Phase 4-1: Istio 설치 (선택적)
# =============================================================================

install_istio() {
    if [ "$SKIP_ISTIO" == "true" ]; then
        log_info "Istio 설치 스킵됨"
        return 0
    fi

    log_step "Phase 4-1: Istio 설치"

    export KUBECONFIG="${KUBECONFIG_FILE}"

    # Istio 설치 확인
    if ! command -v istioctl &>/dev/null; then
        log_info "istioctl 설치 중..."
        curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -
        export PATH="$PWD/istio-1.20.0/bin:$PATH"
    fi

    # 최소 프로파일로 설치
    log_info "Istio 최소 프로파일 설치 중..."
    istioctl install --set profile=minimal -y

    # 네임스페이스에 사이드카 인젝션 활성화
    kubectl label namespace "${NAMESPACE}" istio-injection=enabled --overwrite

    log_success "Istio 설치 완료"
}

# =============================================================================
# Phase 5: ExternalName 서비스 생성 (Docker → K8s 연결)
# =============================================================================

create_external_services() {
    log_step "Phase 5: ExternalName 서비스 생성"

    export KUBECONFIG="${KUBECONFIG_FILE}"

    # Docker 호스트 IP 가져오기 (host.docker.internal 또는 host-gateway)
    local docker_host_ip
    docker_host_ip=$(docker network inspect bridge -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "host.docker.internal")

    # K3d는 host.k3d.internal 사용
    docker_host_ip="host.k3d.internal"

    log_info "Docker 호스트: ${docker_host_ip}"

    # ExternalName 서비스들 생성
    cat <<EOF | kubectl apply -n "${NAMESPACE}" -f -
---
apiVersion: v1
kind: Service
metadata:
  name: customer-db
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: product-db
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 5433
---
apiVersion: v1
kind: Service
metadata:
  name: order-db
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 5434
---
apiVersion: v1
kind: Service
metadata:
  name: store-db
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 5435
---
apiVersion: v1
kind: Service
metadata:
  name: saga-db
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 5436
---
apiVersion: v1
kind: Service
metadata:
  name: payment-db
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 5437
---
apiVersion: v1
kind: Service
metadata:
  name: cache-redis
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: session-redis
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 6380
---
apiVersion: v1
kind: Service
metadata:
  name: kafka
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 9092
---
apiVersion: v1
kind: Service
metadata:
  name: schema-registry
spec:
  type: ExternalName
  externalName: ${docker_host_ip}
  ports:
    - port: 8081
EOF

    log_success "ExternalName 서비스 생성 완료"
}

# =============================================================================
# Phase 6: MSA 서비스 배포 (Helm)
# =============================================================================

deploy_services() {
    log_step "Phase 6: MSA 서비스 배포"

    export KUBECONFIG="${KUBECONFIG_FILE}"

    local charts_dir="${INFRA_REPO_PATH}/charts/services"
    local config_dir="${INFRA_REPO_PATH}/config/dev"
    local ci_values="${PROJECT_ROOT}/config/ci/values-minimal.yaml"

    # 서비스 목록
    local services=("customer-service" "order-service" "product-service" "store-service" "payment-service" "saga-tracker")

    # 첫 번째 서비스 배포 여부
    local first_service_deployed="false"

    for service in "${services[@]}"; do
        local chart_path="${charts_dir}/${service}"
        local values_path="${config_dir}/${service}.yaml"

        if [ ! -d "${chart_path}" ]; then
            log_warn "차트를 찾을 수 없음: ${chart_path}"
            continue
        fi

        log_info "배포 중: ${service}"

        # Helm dependency build (redis-base 등 로컬 dependency 해결)
        log_info "Helm dependency build: ${service}"
        helm dependency build "${chart_path}" 2>/dev/null || {
            log_warn "Dependency build 실패 (무시): ${service}"
        }

        # 첫 번째 서비스 배포 후, AnalysisTemplate 삭제
        # 각 helm chart가 동일한 AnalysisTemplate을 생성하려 하므로
        # 두 번째 서비스부터는 삭제 후 helm이 새로 생성하게 함
        if [ "$first_service_deployed" == "true" ]; then
            log_info "AnalysisTemplate 삭제 중 (충돌 방지)..."
            kubectl delete analysistemplate post-promotion-analysis -n "${NAMESPACE}" 2>/dev/null || true
            kubectl delete analysistemplate smoke-test-analysis -n "${NAMESPACE}" 2>/dev/null || true
        fi

        # Helm 설치/업그레이드
        local helm_args=(
            "upgrade" "--install" "${service}" "${chart_path}"
            "--namespace" "${NAMESPACE}"
            "--wait"
            "--timeout" "5m"
        )

        # 환경별 values 파일 적용
        if [ -f "${values_path}" ]; then
            helm_args+=("-f" "${values_path}")
        fi

        # CI 최소화 values 적용
        if [ -f "${ci_values}" ]; then
            helm_args+=("-f" "${ci_values}")
        fi

        # CI 환경에서는 Redis subchart 비활성화 (ExternalName 서비스 사용)
        helm_args+=("--set" "redis.enabled=false")

        helm "${helm_args[@]}" || {
            log_warn "${service} 배포 실패, 계속 진행..."
        }

        # 첫 번째 성공적인 배포 후 플래그 설정
        if [ "$first_service_deployed" == "false" ]; then
            first_service_deployed="true"
        fi
    done

    log_success "서비스 배포 완료"
}

# =============================================================================
# Phase 7: 서비스 준비 대기
# =============================================================================

wait_for_services() {
    log_step "Phase 7: 서비스 준비 대기"

    export KUBECONFIG="${KUBECONFIG_FILE}"

    local max_wait=180
    local waited=0

    while [ $waited -lt $max_wait ]; do
        local ready_count
        ready_count=$(kubectl get pods -n "${NAMESPACE}" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep -c "True" || echo "0")

        local total_count
        total_count=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l | tr -d ' ')

        if [ "$total_count" -gt 0 ] && [ "$ready_count" -eq "$total_count" ]; then
            log_success "모든 Pod 준비 완료 (${ready_count}/${total_count})"
            break
        fi

        sleep 10
        waited=$((waited + 10))
        log_info "Pod 준비 대기 중... (${waited}s/${max_wait}s, ${ready_count}/${total_count} ready)"
    done

    if [ $waited -ge $max_wait ]; then
        log_warn "일부 Pod가 준비되지 않았습니다."
        kubectl get pods -n "${NAMESPACE}"
    fi

    # 서비스 목록 출력
    log_info "배포된 서비스:"
    kubectl get svc -n "${NAMESPACE}"
}

# =============================================================================
# 결과 출력
# =============================================================================

print_summary() {
    log_step "환경 설정 완료"

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  E2E 테스트 환경 준비 완료${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}KUBECONFIG:${NC} ${KUBECONFIG_FILE}"
    echo -e "${GREEN}Namespace:${NC} ${NAMESPACE}"
    echo ""
    echo -e "${GREEN}다음 단계:${NC}"
    echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
    echo "  ./gradlew test"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    local start_time=$(date +%s)

    # 옵션 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-external-services)
                SKIP_EXTERNAL_SERVICES="true"
                shift
                ;;
            --skip-istio)
                SKIP_ISTIO="true"
                shift
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                exit 1
                ;;
        esac
    done

    log_info "K3d E2E 테스트 환경 설정 시작"

    check_prerequisites
    start_external_services
    create_cluster
    install_argo_rollouts_crd
    install_istio
    create_external_services
    deploy_services
    wait_for_services
    print_summary

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    log_success "총 소요 시간: ${elapsed}초"
}

main "$@"
