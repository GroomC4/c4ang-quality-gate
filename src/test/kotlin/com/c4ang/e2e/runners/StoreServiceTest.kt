package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * Store Service E2E Tests
 * - Store CRUD operations
 */
class StoreServiceTest : TestLifecycleHooks() {

    @Karate.Test
    fun testCreateStore(): Karate {
        return Karate.run("classpath:features/store/create-store.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testGetStore(): Karate {
        return Karate.run("classpath:features/store/get-store.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testUpdateStore(): Karate {
        return Karate.run("classpath:features/store/update-store.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testDeleteStore(): Karate {
        return Karate.run("classpath:features/store/delete-store.feature")
            .relativeTo(javaClass)
    }
}
