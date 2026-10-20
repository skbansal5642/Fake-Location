package com.spurge.fake_location

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Persists the configuration so the service can run without the Flutter UI. */
object ConfigStore {
    private const val PREFS = "fake_location"
    private const val KEY_CONFIG = "config"
    private const val KEY_LEGACY_SLOTS = "slots"
    private const val KEY_ENABLED = "enabled"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun saveJson(context: Context, json: String) {
        MockConfig.fromJson(JSONObject(json)) // validate before persisting
        prefs(context).edit().putString(KEY_CONFIG, json).apply()
    }

    fun loadJson(context: Context): String {
        prefs(context).getString(KEY_CONFIG, null)?.let { return it }
        // Schedules saved before modes existed are stored as a bare slot list.
        val legacy = JSONArray(prefs(context).getString(KEY_LEGACY_SLOTS, "[]"))
        val slots = (0 until legacy.length()).map { Slot.fromJson(legacy.getJSONObject(it)) }
        return MockConfig(slots = slots).toJson().toString()
    }

    fun load(context: Context): MockConfig = MockConfig.fromJson(JSONObject(loadJson(context)))

    /** Whether the user wants the service running; used to resume it after a reboot. */
    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    fun isEnabled(context: Context): Boolean = prefs(context).getBoolean(KEY_ENABLED, false)
}
