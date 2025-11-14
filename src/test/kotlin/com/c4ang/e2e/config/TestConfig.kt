package com.c4ang.e2e.config

import io.fabric8.kubernetes.client.KubernetesClientBuilder
import io.fabric8.kubernetes.client.LocalPortForward
import org.slf4j.LoggerFactory
import java.io.File
import java.util.concurrent.TimeUnit

object TestConfig {
    private val logger = LoggerFactory.getLogger(TestConfig::class.java)
    private var portForward: LocalPortForward? = null

    val namespace: String = System.getProperty("k8s.namespace", "msa-quality")
    val kubeConfigPath: String = System.getProperty("kubeconfig.path",
        "${System.getProperty("user.dir")}/c4ang-infra/k8s-dev-k3d/kubeconfig/config")
    val localPort: Int = System.getProperty("local.port", "8080").toInt()

    /**
     * K8s 서비스로 Port-Forward 설정
     * 로컬 테스트 시 K3d 클러스터의 서비스에 접근하기 위해 사용
     */
    fun setupPortForward(serviceName: String, servicePort: Int = 8080): Int {
        logger.info("Setting up port-forward: $serviceName:$servicePort -> localhost:$localPort")

        val kubeConfig = File(kubeConfigPath)
        if (!kubeConfig.exists()) {
            logger.warn("Kubeconfig not found at: $kubeConfigPath. Skipping port-forward.")
            logger.info("Assuming services are already accessible on localhost:$localPort")
            return localPort
        }

        try {
            System.setProperty("kubeconfig", kubeConfigPath)

            val client = KubernetesClientBuilder()
                .build()

            // 서비스에 연결된 Pod 찾기
            val pods = client.pods()
                .inNamespace(namespace)
                .withLabel("app", serviceName)
                .list()
                .items

            if (pods.isEmpty()) {
                logger.warn("No pods found for service: $serviceName in namespace: $namespace")
                logger.info("Skipping port-forward. Make sure services are deployed.")
                return localPort
            }

            val pod = pods.first()
            logger.info("Port-forwarding to pod: ${pod.metadata.name}")

            // Port-forward 설정
            portForward = client.pods()
                .inNamespace(namespace)
                .withName(pod.metadata.name)
                .portForward(servicePort, localPort)

            // Port-forward가 준비될 때까지 대기
            var retries = 0
            while (!isPortReady(localPort) && retries < 10) {
                TimeUnit.MILLISECONDS.sleep(500)
                retries++
            }

            if (isPortReady(localPort)) {
                logger.info("Port-forward ready: localhost:$localPort -> ${pod.metadata.name}:$servicePort")
            } else {
                logger.warn("Port-forward setup completed but port may not be ready yet")
            }

            return localPort
        } catch (e: Exception) {
            logger.error("Failed to setup port-forward: ${e.message}", e)
            logger.info("Continuing without port-forward. Ensure services are accessible.")
            return localPort
        }
    }

    /**
     * Port-Forward 정리
     */
    fun cleanupPortForward() {
        portForward?.let {
            logger.info("Closing port-forward...")
            try {
                it.close()
                logger.info("Port-forward closed successfully")
            } catch (e: Exception) {
                logger.error("Error closing port-forward: ${e.message}", e)
            }
        }
    }

    /**
     * 로컬 포트가 사용 가능한지 확인
     */
    private fun isPortReady(port: Int): Boolean {
        return try {
            java.net.Socket("localhost", port).use { true }
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 테스트 환경 초기화
     * - Port-forward 설정 (로컬 환경인 경우)
     * - 환경 검증
     */
    fun initialize() {
        logger.info("Initializing test environment...")
        logger.info("Namespace: $namespace")
        logger.info("Kubeconfig: $kubeConfigPath")
        logger.info("Environment: ${System.getProperty("karate.env", "local")}")

        val env = System.getProperty("karate.env", "local")
        if (env == "local") {
            // 로컬 환경에서는 Port-forward 설정 (선택적)
            // setupPortForward("customer-service", 8080)
            logger.info("Local environment detected. Port-forward can be set up manually if needed.")
        }

        logger.info("Test environment initialized successfully")
    }

    /**
     * 테스트 환경 정리
     */
    fun cleanup() {
        logger.info("Cleaning up test environment...")
        cleanupPortForward()
        logger.info("Test environment cleanup completed")
    }
}
