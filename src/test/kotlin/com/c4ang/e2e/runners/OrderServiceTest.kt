package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * Order Service E2E Tests
 * - Order creation with SAGA
 * - Order cancellation
 * - Order queries
 */
class OrderServiceTest : TestLifecycleHooks() {

    @Karate.Test
    fun testCreateOrder(): Karate {
        return Karate.run("classpath:features/order/create-order.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testCancelOrder(): Karate {
        return Karate.run("classpath:features/order/cancel-order.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testGetOrders(): Karate {
        return Karate.run("classpath:features/order/get-orders.feature")
            .relativeTo(javaClass)
    }
}
