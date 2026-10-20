package com.spurge.fake_location

import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

/** Wanders slowly inside a radius around a center, like the fix of a phone lying still. */
class Drift(private val random: Random = Random.Default) {
    private var north = 0.0
    private var east = 0.0
    private var targetNorth = 0.0
    private var targetEast = 0.0
    private var accuracy = 6f

    /** Advances one tick and returns the (north, east) offset in meters, always within [radiusM]. */
    fun next(radiusM: Double): Pair<Double, Double> {
        if (radiusM <= 0) {
            reset()
            return 0.0 to 0.0
        }
        if (hypot(targetNorth, targetEast) > radiusM || hypot(targetNorth - north, targetEast - east) < STEP_M) {
            pickTarget(radiusM)
        }
        val dn = targetNorth - north
        val de = targetEast - east
        val d = hypot(dn, de)
        val step = minOf(STEP_M * (0.5 + random.nextDouble()), d)
        if (d > 0) {
            north += dn / d * step
            east += de / d * step
        }
        // Keep inside the circle even if the radius shrank since the last tick.
        val r = hypot(north, east)
        if (r > radiusM) {
            north *= radiusM / r
            east *= radiusM / r
        }
        return north to east
    }

    /** A reported accuracy in meters that changes gradually between 3 and 12. */
    fun nextAccuracy(): Float {
        accuracy = (accuracy + (random.nextFloat() - 0.5f)).coerceIn(3f, 12f)
        return accuracy
    }

    fun reset() {
        north = 0.0; east = 0.0; targetNorth = 0.0; targetEast = 0.0
    }

    private fun pickTarget(radiusM: Double) {
        // sqrt spreads targets evenly over the disc instead of clustering at the center.
        val r = radiusM * sqrt(random.nextDouble())
        val angle = random.nextDouble() * 2 * Math.PI
        targetNorth = r * cos(angle)
        targetEast = r * sin(angle)
    }

    companion object {
        /** Meters moved per tick, so the point crosses a 10 m radius in tens of seconds. */
        const val STEP_M = 0.4
    }
}
