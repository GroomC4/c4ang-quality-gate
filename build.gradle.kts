plugins {
    kotlin("jvm") version "2.0.21"
    id("java")
}

group = "com.c4ang"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    // Karate Testing Framework
    testImplementation("com.intuit.karate:karate-junit5:1.4.1")

    // JUnit 5
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")

    // Kubernetes Client (for port-forwarding and cluster interaction)
    testImplementation("io.fabric8:kubernetes-client:6.13.1")

    // Logging
    testImplementation("ch.qos.logback:logback-classic:1.5.6")
    testImplementation("org.slf4j:slf4j-api:2.0.13")

    // Kotlin Standard Library
    implementation(kotlin("stdlib"))
}

tasks.test {
    useJUnitPlatform()

    systemProperty("karate.options", System.getProperty("karate.options") ?: "")
    systemProperty("karate.env", System.getProperty("karate.env") ?: "local")

    outputs.upToDateWhen { false }

    testLogging {
        events("passed", "skipped", "failed")
        showStandardStreams = true
    }
}

kotlin {
    jvmToolchain(21)
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

// Karate 리포트 생성
tasks.register("karateReport") {
    doLast {
        val reportDir = file("build/karate-reports")
        if (reportDir.exists()) {
            println("Karate report generated at: ${reportDir.absolutePath}")
        }
    }
}

tasks.named("test") {
    finalizedBy("karateReport")
}
