package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * E2E 통합 시나리오 테스트 러너
 */
class E2EScenarioTest : TestLifecycleHooks() {

    @Karate.Test
    fun testEndToEndCustomerFlow(): Karate {
        return Karate.run("classpath:features/scenario/end-to-end-customer-flow.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testMultiServiceIntegration(): Karate {
        return Karate.run("classpath:features/scenario/multi-service-integration.feature")
            .relativeTo(javaClass)
    }
}
