package com.spurge.fake_location

import org.json.JSONArray
import org.json.JSONObject

/** A named point on the map. */
data class Place(val name: String, val lat: Double, val lng: Double) {
    fun toJson(): JSONObject = JSONObject().put("name", name).put("lat", lat).put("lng", lng)

    companion object {
        fun fromJson(o: JSONObject) = Place(o.getString("name"), o.getDouble("lat"), o.getDouble("lng"))
    }
}

/** A location reported during a daily time window given in minutes from midnight. */
data class Slot(
    val name: String,
    val lat: Double,
    val lng: Double,
    val startMinute: Int,
    val endMinute: Int,
) {
    val place get() = Place(name, lat, lng)

    /** Windows where start > end wrap past midnight; start == end means all day. */
    fun contains(minute: Int): Boolean = when {
        startMinute == endMinute -> true
        startMinute < endMinute -> minute in startMinute until endMinute
        else -> minute >= startMinute || minute < endMinute
    }

    fun toJson(): JSONObject = JSONObject()
        .put("name", name).put("lat", lat).put("lng", lng)
        .put("start", startMinute).put("end", endMinute)

    companion object {
        fun fromJson(o: JSONObject) = Slot(
            o.getString("name"), o.getDouble("lat"), o.getDouble("lng"),
            o.getInt("start"), o.getInt("end"),
        )
    }
}

/** Shows [target] while the device is within [radiusMeters] of [anchor] or connected to [ssid]. */
data class Rule(
    val name: String,
    val anchor: Place,
    val radiusMeters: Double,
    val ssid: String?,
    val target: Place,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("name", name)
        .put("anchor", anchor.toJson())
        .put("radius", radiusMeters)
        .put("ssid", ssid ?: JSONObject.NULL)
        .put("target", target.toJson())

    companion object {
        fun fromJson(o: JSONObject) = Rule(
            name = o.getString("name"),
            anchor = Place.fromJson(o.getJSONObject("anchor")),
            radiusMeters = o.optDouble("radius", DEFAULT_RADIUS_M),
            ssid = o.optString("ssid").takeIf { !o.isNull("ssid") && it.isNotBlank() },
            target = Place.fromJson(o.getJSONObject("target")),
        )

        const val DEFAULT_RADIUS_M = 60.0
    }
}

enum class Mode(val id: String) {
    SCHEDULE("schedule"), FIXED("fixed"), RULES("rules");

    companion object {
        fun of(id: String?) = entries.firstOrNull { it.id == id } ?: SCHEDULE
    }
}

/** Everything the service needs to decide what location to report. */
data class MockConfig(
    val mode: Mode = Mode.SCHEDULE,
    val slots: List<Slot> = emptyList(),
    val fixed: Place? = null,
    val rules: List<Rule> = emptyList(),
    val driftMeters: Double = DEFAULT_DRIFT_M,
) {
    /** Whether the active mode has something to report. */
    val isRunnable: Boolean
        get() = when (mode) {
            Mode.SCHEDULE -> slots.isNotEmpty()
            Mode.FIXED -> fixed != null
            Mode.RULES -> rules.isNotEmpty()
        }

    fun toJson(): JSONObject = JSONObject()
        .put("mode", mode.id)
        .put("slots", JSONArray(slots.map { it.toJson() }))
        .put("fixed", fixed?.toJson() ?: JSONObject.NULL)
        .put("rules", JSONArray(rules.map { it.toJson() }))
        .put("drift", driftMeters)

    companion object {
        const val DEFAULT_DRIFT_M = 10.0

        fun fromJson(o: JSONObject) = MockConfig(
            mode = Mode.of(o.optString("mode")),
            slots = o.optJSONArray("slots").objects().map(Slot::fromJson),
            fixed = o.optJSONObject("fixed")?.let(Place::fromJson),
            rules = o.optJSONArray("rules").objects().map(Rule::fromJson),
            driftMeters = o.optDouble("drift", DEFAULT_DRIFT_M),
        )

        private fun JSONArray?.objects(): List<JSONObject> =
            if (this == null) emptyList() else (0 until length()).map { getJSONObject(it) }
    }
}
