package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * SAGA Flow E2E Tests
 * - Full purchase flow
 * - SAGA compensation flow
 */
class SagaFlowTest : TestLifecycleHooks() {

    @Karate.Test
    fun testFullPurchaseFlow(): Karate {
        return Karate.run("classpath:features/scenario/full-purchase-flow.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testSagaCompensationFlow(): Karate {
        return Karate.run("classpath:features/scenario/saga-compensation-flow.feature")
            .relativeTo(javaClass)
    }
}
