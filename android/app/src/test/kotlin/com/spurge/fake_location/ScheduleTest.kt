package com.spurge.fake_location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class ScheduleTest {

    private val day = Slot("A", 1.0, 1.0, 8 * 60, 20 * 60)
    private val night = Slot("B", 2.0, 2.0, 20 * 60, 8 * 60)

    private fun at(hour: Int, minute: Int): Calendar =
        Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, hour); set(Calendar.MINUTE, minute) }

    @Test
    fun dayWindowIncludesStartExcludesEnd() {
        assertTrue(day.contains(8 * 60))
        assertTrue(day.contains(20 * 60 - 1))
        assertFalse(day.contains(20 * 60))
        assertFalse(day.contains(7 * 60 + 59))
    }

    @Test
    fun windowWrapsPastMidnight() {
        assertTrue(night.contains(20 * 60))
        assertTrue(night.contains(23 * 60 + 59))
        assertTrue(night.contains(0))
        assertTrue(night.contains(7 * 60 + 59))
        assertFalse(night.contains(8 * 60))
        assertFalse(night.contains(12 * 60))
    }

    @Test
    fun equalStartAndEndMeansAllDay() {
        val allDay = Slot("C", 0.0, 0.0, 300, 300)
        assertTrue(allDay.contains(0))
        assertTrue(allDay.contains(299))
        assertTrue(allDay.contains(1439))
    }

    @Test
    fun currentSwitchesAtBoundaries() {
        val slots = listOf(day, night)
        assertEquals("A", Schedule.current(slots, at(9, 50))?.name)
        assertEquals("A", Schedule.current(slots, at(19, 59))?.name)
        assertEquals("B", Schedule.current(slots, at(20, 0))?.name)
        assertEquals("B", Schedule.current(slots, at(3, 0))?.name)
        assertEquals("A", Schedule.current(slots, at(8, 0))?.name)
    }

    @Test
    fun currentFallsBackToFirstSlotOutsideAllWindows() {
        val morning = Slot("M", 0.0, 0.0, 6 * 60, 9 * 60)
        assertEquals("M", Schedule.current(listOf(morning), at(22, 0))?.name)
        assertNull(Schedule.current(emptyList(), at(22, 0)))
    }
}
