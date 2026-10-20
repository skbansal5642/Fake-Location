package com.spurge.fake_location

import org.junit.Assert.assertEquals
import org.junit.Test

class GeoTest {

    @Test
    fun distanceBetweenKnownPoints() {
        // Connaught Place to India Gate, Delhi: about 2.4 km.
        val d = Geo.distanceMeters(28.6315, 77.2167, 28.6129, 77.2295)
        assertEquals(2400.0, d, 100.0)
    }

    @Test
    fun offsetMovesByRequestedMeters() {
        val (lat, lng) = Geo.offset(28.6, 77.2, northM = 30.0, eastM = 40.0)
        assertEquals(50.0, Geo.distanceMeters(28.6, 77.2, lat, lng), 0.1)
    }
}
