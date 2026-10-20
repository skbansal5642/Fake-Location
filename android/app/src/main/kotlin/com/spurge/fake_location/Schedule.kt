package com.spurge.fake_location

import java.util.Calendar

object Schedule {
    /** The first slot whose window contains now, falling back to the first slot. */
    fun current(slots: List<Slot>, now: Calendar = Calendar.getInstance()): Slot? {
        val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        return slots.firstOrNull { it.contains(minute) } ?: slots.firstOrNull()
    }
}
