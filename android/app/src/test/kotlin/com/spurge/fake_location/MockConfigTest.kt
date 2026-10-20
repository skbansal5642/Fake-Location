package com.spurge.fake_location

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MockConfigTest {

    @Test
    fun roundTripsThroughJson() {
        val config = MockConfig(
            mode = Mode.RULES,
            slots = listOf(Slot("A", 1.0, 2.0, 480, 1200)),
            fixed = Place("F", 3.0, 4.0),
            rules = listOf(Rule("R", Place("X", 5.0, 6.0), 60.0, "Home", Place("Y", 7.0, 8.0))),
            driftMeters = 15.0,
        )
        assertEquals(config, MockConfig.fromJson(JSONObject(config.toJson().toString())))
    }

    @Test
    fun nullAndBlankSsidMeanNoWifiRule() {
        val rule = Rule("R", Place("X", 5.0, 6.0), 60.0, null, Place("Y", 7.0, 8.0))
        assertEquals(null, Rule.fromJson(JSONObject(rule.toJson().toString())).ssid)
        val blank = rule.toJson().put("ssid", "  ")
        assertEquals(null, Rule.fromJson(blank).ssid)
    }

    @Test
    fun missingFieldsUseDefaults() {
        val config = MockConfig.fromJson(JSONObject("{}"))
        assertEquals(Mode.SCHEDULE, config.mode)
        assertEquals(MockConfig.DEFAULT_DRIFT_M, config.driftMeters, 0.0)
        assertFalse(config.isRunnable)
    }

    @Test
    fun runnableDependsOnMode() {
        val fixed = MockConfig(mode = Mode.FIXED, fixed = Place("F", 1.0, 1.0))
        assertTrue(fixed.isRunnable)
        assertFalse(fixed.copy(mode = Mode.RULES).isRunnable)
    }
}
