package com.c4ang.e2e

import com.c4ang.e2e.config.TestConfig
import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll

/**
 * 전체 테스트 수행 시 공통으로 실행되는 라이프사이클 훅
 */
abstract class TestLifecycleHooks {
    companion object {
        @JvmStatic
        @BeforeAll
        fun globalSetup() {
            TestConfig.initialize()
        }

        @JvmStatic
        @AfterAll
        fun globalCleanup() {
            TestConfig.cleanup()
        }
    }
}
