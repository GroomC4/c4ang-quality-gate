package com.c4ang.e2e.runners

import com.c4ang.e2e.TestLifecycleHooks
import com.intuit.karate.junit5.Karate

/**
 * 모든 E2E 테스트를 실행하는 통합 러너
 *
 * 사용법:
 * ./gradlew test --tests AllTestsRunner
 *
 * 태그로 필터링:
 * ./gradlew test --tests AllTestsRunner -Dkarate.options="--tags @happy-path"
 * ./gradlew test --tests AllTestsRunner -Dkarate.options="--tags @saga"
 */
class AllTestsRunner : TestLifecycleHooks() {

    @Karate.Test
    fun testAll(): Karate {
        return Karate.run("classpath:features")
            .relativeTo(javaClass)
            .reportDir("build/karate-reports")
    }

    @Karate.Test
    fun testHappyPathOnly(): Karate {
        return Karate.run("classpath:features")
            .relativeTo(javaClass)
            .tags("@happy-path")
            .reportDir("build/karate-reports")
    }

    @Karate.Test
    fun testSagaFlows(): Karate {
        return Karate.run("classpath:features")
            .relativeTo(javaClass)
            .tags("@saga")
            .reportDir("build/karate-reports")
    }
}
