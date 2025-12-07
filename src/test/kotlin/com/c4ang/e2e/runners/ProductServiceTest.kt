package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * Product Service E2E Tests
 * - Product registration
 * - Product search/retrieval
 * - Product update/delete
 */
class ProductServiceTest : TestLifecycleHooks() {

    @Karate.Test
    fun testRegisterProduct(): Karate {
        return Karate.run("classpath:features/product/register-product.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testSearchProduct(): Karate {
        return Karate.run("classpath:features/product/search-product.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testUpdateProduct(): Karate {
        return Karate.run("classpath:features/product/update-product.feature")
            .relativeTo(javaClass)
    }

    @Karate.Test
    fun testDeleteProduct(): Karate {
        return Karate.run("classpath:features/product/delete-product.feature")
            .relativeTo(javaClass)
    }
}
