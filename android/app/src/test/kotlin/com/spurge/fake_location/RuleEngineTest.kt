package com.spurge.fake_location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RuleEngineTest {

    private val office = Place("Office", 28.5355, 77.3910)
    private val home = Place("Home", 28.6139, 77.2090)
    private val rule = Rule("Office→Home", office, 60.0, "OfficeWiFi", home)

    private val atOffice = Surroundings(null, setOf("aa:aa", "bb:bb"), setOf("lte:1:1"))
    private val elsewhere = Surroundings(null, setOf("cc:cc"), setOf("lte:9:9"))

    private fun fixAt(place: Place, northM: Double, timeMs: Long, accuracy: Float = 8f): Fix {
        val (lat, lng) = Geo.offset(place.lat, place.lng, northM, 0.0)
        return Fix(lat, lng, accuracy, timeMs)
    }

    /** Runs evaluations every 15 s from [fromMs], returning the time after the last one. */
    private fun RuleEngine.run(fromMs: Long, times: Int, fix: Fix?, s: Surroundings): Long {
        var t = fromMs
        repeat(times) { evaluate(t, fix, s); t += 15_000 }
        return t
    }

    @Test
    fun entersInsideRadiusOnly() {
        val engine = RuleEngine(listOf(rule))
        assertNull(engine.evaluate(1_000, fixAt(office, 80.0, 1_000), elsewhere))
        assertEquals(rule, engine.evaluate(2_000, fixAt(office, 50.0, 2_000), atOffice))
    }

    @Test
    fun ignoresInaccurateOrStaleFixes() {
        val engine = RuleEngine(listOf(rule))
        assertNull(engine.evaluate(1_000, fixAt(office, 0.0, 1_000, accuracy = 200f), atOffice))
        assertNull(engine.evaluate(200_000, fixAt(office, 0.0, 1_000), atOffice))
    }

    @Test
    fun entersAndExitsByWifi() {
        val engine = RuleEngine(listOf(rule))
        val onWifi = atOffice.copy(ssid = "OfficeWiFi")
        assertEquals(rule, engine.evaluate(0, null, onWifi))
        // Brief disconnects are tolerated.
        var t = engine.run(15_000, RuleEngine.WIFI_EXIT_MISSES - 1, null, atOffice)
        assertEquals(rule, engine.evaluate(t, null, onWifi))
        t = engine.run(t + 15_000, RuleEngine.WIFI_EXIT_MISSES, null, atOffice)
        assertNull(engine.active)
    }

    @Test
    fun staysWhileSurroundingsMatchAndExitsWhenTheyChange() {
        val engine = RuleEngine(listOf(rule))
        engine.evaluate(0, fixAt(office, 10.0, 0), atOffice)
        var t = engine.run(15_000, 20, null, atOffice)
        assertEquals(rule, engine.active)
        t = engine.run(t, RuleEngine.SURROUNDINGS_EXIT_MISSES - 1, null, elsewhere)
        assertEquals(rule, engine.active)
        engine.run(t, 1, null, elsewhere)
        assertNull(engine.active)
    }

    @Test
    fun missingDataDoesNotCountAsLeaving() {
        val engine = RuleEngine(listOf(rule))
        engine.evaluate(0, fixAt(office, 10.0, 0), atOffice)
        engine.run(200_000, 20, null, Surroundings.NONE)
        assertEquals(rule, engine.active)
    }

    @Test
    fun learnsSurroundingsDuringWarmup() {
        val engine = RuleEngine(listOf(rule))
        engine.evaluate(0, fixAt(office, 10.0, 0), Surroundings(null, setOf("aa:aa"), emptySet()))
        // An access point first seen during warm-up keeps the rule active afterwards.
        engine.evaluate(60_000, null, Surroundings(null, setOf("dd:dd"), emptySet()))
        engine.run(200_000, 10, null, Surroundings(null, setOf("dd:dd"), emptySet()))
        assertEquals(rule, engine.active)
    }

    @Test
    fun doesNotReenterFromFixTakenBeforeExit() {
        val engine = RuleEngine(listOf(rule))
        engine.evaluate(0, fixAt(office, 10.0, 0), atOffice)
        val t = engine.run(200_000, RuleEngine.SURROUNDINGS_EXIT_MISSES, null, elsewhere)
        assertNull(engine.active)
        // Fresh enough, but taken before the exit was detected.
        val beforeExit = fixAt(office, 10.0, t - 20_000)
        assertNull(engine.evaluate(t, beforeExit, elsewhere))
        // A fix taken after the exit still re-enters.
        assertEquals(rule, engine.evaluate(t + 1_000, fixAt(office, 10.0, t + 500), elsewhere))
    }

    @Test
    fun flagsExitBlindWhenNoRadioData() {
        val engine = RuleEngine(listOf(rule))
        engine.evaluate(0, fixAt(office, 10.0, 0), Surroundings.NONE)
        assertFalse(engine.isExitBlind)
        engine.run(15_000, 10, null, Surroundings.NONE)
        assertTrue(engine.isExitBlind)
    }
}
