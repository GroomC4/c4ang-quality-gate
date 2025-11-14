package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * 모든 E2E 테스트를 실행하는 통합 러너
 *
 * 사용법:
 * ./gradlew test --tests AllTestsRunner
 */
class AllTestsRunner : TestLifecycleHooks() {

    @Karate.Test
    fun testAll(): Karate {
        return Karate.run("classpath:features")
            .relativeTo(javaClass)
            .reportDir("build/karate-reports")
    }
}
