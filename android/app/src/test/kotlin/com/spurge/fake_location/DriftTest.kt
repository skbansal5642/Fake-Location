package com.spurge.fake_location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot
import kotlin.random.Random

class DriftTest {

    @Test
    fun staysWithinRadiusAndMovesSlowly() {
        val drift = Drift(Random(42))
        var prev = 0.0 to 0.0
        var maxR = 0.0
        repeat(5000) {
            val p = drift.next(10.0)
            val r = hypot(p.first, p.second)
            assertTrue("outside radius: $r", r <= 10.0 + 1e-9)
            assertTrue("jumped too far", hypot(p.first - prev.first, p.second - prev.second) <= Drift.STEP_M * 1.5 + 1e-9)
            maxR = maxOf(maxR, r)
            prev = p
        }
        assertTrue("never wandered: $maxR", maxR > 5.0)
    }

    @Test
    fun zeroRadiusMeansNoOffset() {
        val drift = Drift(Random(1))
        repeat(10) { drift.next(10.0) }
        assertEquals(0.0 to 0.0, drift.next(0.0))
    }

    @Test
    fun shrinkingRadiusPullsPointInside() {
        val drift = Drift(Random(7))
        repeat(500) { drift.next(30.0) }
        val p = drift.next(5.0)
        assertTrue(hypot(p.first, p.second) <= 5.0 + 1e-9)
    }

    @Test
    fun accuracyStaysInRange() {
        val drift = Drift(Random(3))
        repeat(1000) { assertTrue(drift.nextAccuracy() in 3f..12f) }
    }
}
