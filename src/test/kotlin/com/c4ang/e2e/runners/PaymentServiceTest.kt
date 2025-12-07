package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * Payment Service E2E Tests
 * - Payment request
 * - Payment queries
 */
class PaymentServiceTest : TestLifecycleHooks() {

    @Karate.Test
    fun testRequestPayment(): Karate {
        return Karate.run("classpath:features/payment/request-payment.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testGetPayment(): Karate {
        return Karate.run("classpath:features/payment/get-payment.feature")
            .relativeTo(javaClass)
    }
}
