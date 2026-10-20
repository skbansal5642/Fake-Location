package com.spurge.fake_location

/** A real (non-mock) position fix. */
data class Fix(val lat: Double, val lng: Double, val accuracyM: Float, val elapsedMs: Long)

/** Radio surroundings that stay real while a mock location is active. */
data class Surroundings(
    val ssid: String?,
    val bssids: Set<String>,
    val cells: Set<String>,
) {
    val isEmpty get() = bssids.isEmpty() && cells.isEmpty()

    companion object {
        val NONE = Surroundings(null, emptySet(), emptySet())
    }
}

/**
 * Decides which rule is active.
 *
 * Entry uses a fresh real fix inside a rule's radius, or the rule's Wi-Fi being connected.
 * While active the real position is hidden by the mock, so leaving is detected from radio
 * surroundings: losing the rule's Wi-Fi, or no longer seeing any Wi-Fi access point or cell
 * that was visible on arrival.
 */
class RuleEngine(private val rules: List<Rule>) {

    var active: Rule? = null
        private set

    /** True when the active rule has no radio fingerprint, so leaving cannot be detected. */
    val isExitBlind: Boolean
        get() = active != null && !enteredByWifi && nowMs - activatedAtMs > WARMUP_MS &&
            anchorBssids.isEmpty() && anchorCells.isEmpty()

    private var enteredByWifi = false
    private var activatedAtMs = 0L
    private var inactiveSinceMs = Long.MIN_VALUE
    private var misses = 0
    private var nowMs = 0L
    private val anchorBssids = mutableSetOf<String>()
    private val anchorCells = mutableSetOf<String>()

    /** Updates the decision; [nowMs] is elapsed realtime and [fix] the latest real fix, if any. */
    fun evaluate(nowMs: Long, fix: Fix?, surroundings: Surroundings): Rule? {
        this.nowMs = nowMs
        val current = active
        if (current == null) {
            tryEnter(nowMs, fix, surroundings)
        } else {
            checkExit(current, nowMs, surroundings)
        }
        return active
    }

    private fun tryEnter(nowMs: Long, fix: Fix?, s: Surroundings) {
        val byWifi = s.ssid?.let { ssid -> rules.firstOrNull { it.ssid == ssid } }
        // Ignore fixes from before the last exit: they describe where the device used to be.
        val usableFix = fix?.takeIf {
            it.elapsedMs > inactiveSinceMs && nowMs - it.elapsedMs <= MAX_FIX_AGE_MS && it.accuracyM <= MAX_ACCURACY_M
        }
        val byGeo = usableFix?.let { f ->
            rules.firstOrNull { Geo.distanceMeters(f.lat, f.lng, it.anchor.lat, it.anchor.lng) <= it.radiusMeters }
        }
        val rule = byWifi ?: byGeo ?: return
        active = rule
        enteredByWifi = byWifi != null
        activatedAtMs = nowMs
        misses = 0
        anchorBssids.clear()
        anchorCells.clear()
        anchorBssids += s.bssids
        anchorCells += s.cells
    }

    private fun checkExit(rule: Rule, nowMs: Long, s: Surroundings) {
        val onRuleWifi = rule.ssid != null && s.ssid == rule.ssid
        if (enteredByWifi) {
            misses = if (onRuleWifi) 0 else misses + 1
            if (misses >= WIFI_EXIT_MISSES) exit(nowMs)
            return
        }
        // Learn the place's surroundings for a short while after arriving.
        if (nowMs - activatedAtMs <= WARMUP_MS) {
            anchorBssids += s.bssids
            anchorCells += s.cells
            return
        }
        val stillHere = onRuleWifi || s.bssids.any { it in anchorBssids } || s.cells.any { it in anchorCells }
        when {
            stillHere -> misses = 0
            !s.isEmpty -> misses++ // only count evidence of being elsewhere, not missing data
        }
        if (misses >= SURROUNDINGS_EXIT_MISSES) exit(nowMs)
    }

    private fun exit(nowMs: Long) {
        active = null
        inactiveSinceMs = nowMs
        misses = 0
    }

    companion object {
        const val MAX_FIX_AGE_MS = 60_000L
        const val MAX_ACCURACY_M = 50f
        const val WARMUP_MS = 120_000L
        const val WIFI_EXIT_MISSES = 6
        const val SURROUNDINGS_EXIT_MISSES = 3
    }
}
