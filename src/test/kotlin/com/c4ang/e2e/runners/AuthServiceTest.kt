package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * Authentication Service E2E Tests
 * - Customer signup/login
 * - Owner signup/login
 * - Token refresh
 */
class AuthServiceTest : TestLifecycleHooks() {

    @Karate.Test
    fun testCustomerSignup(): Karate {
        return Karate.run("classpath:features/auth/customer-signup.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testCustomerLogin(): Karate {
        return Karate.run("classpath:features/auth/customer-login.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testOwnerSignup(): Karate {
        return Karate.run("classpath:features/auth/owner-signup.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testOwnerLogin(): Karate {
        return Karate.run("classpath:features/auth/owner-login.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testTokenRefresh(): Karate {
        return Karate.run("classpath:features/auth/token-refresh.feature")
            .relativeTo(javaClass)
    }
}
