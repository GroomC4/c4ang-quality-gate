package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * Customer Service E2E 테스트 러너
 */
class CustomerServiceTest : TestLifecycleHooks() {

    @Karate.Test
    fun testAuth(): Karate {
        return Karate.run("classpath:features/auth/login.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testCreateCustomer(): Karate {
        return Karate.run("classpath:features/customer/create-customer.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testGetCustomer(): Karate {
        return Karate.run("classpath:features/customer/get-customer.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testUpdateCustomer(): Karate {
        return Karate.run("classpath:features/customer/update-customer.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testDeleteCustomer(): Karate {
        return Karate.run("classpath:features/customer/delete-customer.feature")
            .relativeTo(javaClass)
    }
}
