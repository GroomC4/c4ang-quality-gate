package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * Customer Service E2E Tests
 * - Customer signup/login
 * - Owner signup/login
 * - Token refresh
 */
class CustomerServiceTest : TestLifecycleHooks() {

    @Karate.Test
    fun testCustomerSignup(): Karate {
        return Karate.run("classpath:features/customer/customer-signup.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testCustomerLogin(): Karate {
        return Karate.run("classpath:features/customer/customer-login.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testOwnerSignup(): Karate {
        return Karate.run("classpath:features/customer/owner-signup.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testOwnerLogin(): Karate {
        return Karate.run("classpath:features/customer/owner-login.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testTokenRefresh(): Karate {
        return Karate.run("classpath:features/customer/token-refresh.feature")
            .relativeTo(javaClass)
    }
}
