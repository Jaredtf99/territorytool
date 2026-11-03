package com.jared.territorytool

import com.jared.territorytool.core.network.Dates
import com.jared.territorytool.features.quickaction.naturalCompare
import com.jared.territorytool.features.territories.map.TerritoryMapGeometryPreprocessor
import com.jared.territorytool.features.territories.map.TerritoryMapGeometryPreprocessor.Point
import com.jared.territorytool.features.territories.map.signedDistance
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class CoreLogicTest {
    @Test
    fun parsesAllPostgrestDateVariants() {
        val expected = Instant.parse("2025-03-12T10:15:30Z")
        listOf(
            "2025-03-12T10:15:30Z",
            "2025-03-12T10:15:30+00:00",
            "2025-03-12T10:15:30.000Z",
            "2025-03-12T10:15:30.000000+00:00",
            "2025-03-12T11:15:30+01:00",
        ).forEach { assertEquals(it, expected, Dates.parse(it)) }
    }

    @Test
    fun naturalOrderComparesNumbersByValue() {
        val sorted = listOf("AV10", "AV2", "AV1", "B1").sortedWith(::naturalCompare)
        assertEquals(listOf("AV1", "AV2", "AV10", "B1"), sorted)
    }

    @Test
    fun polylabelLandsInsideConcavePolygon() {
        // Forma de "L": el centroide cae fuera, el polylabel debe quedar dentro.
        val l = listOf(Point(0.0, 0.0), Point(100.0, 0.0), Point(100.0, 20.0), Point(20.0, 20.0), Point(20.0, 100.0), Point(0.0, 100.0))
        val placement = TerritoryMapGeometryPreprocessor.polylabel(l)
        assertNotNull(placement)
        assertTrue(signedDistance(placement!!.point, l) > 0)
    }

    @Test
    fun neighbourBordersConvergeToMidline() {
        // Dos cuadrados que se solapan 10 m: los vértices invasores se mueven a media distancia.
        val a = TerritoryMapGeometryPreprocessor.Feature(1, "a", listOf(Point(0.0, 30.0), Point(110.0, 30.0), Point(110.0, 70.0), Point(0.0, 70.0), Point(0.0, 30.0)))
        val b = TerritoryMapGeometryPreprocessor.Feature(2, "b", listOf(Point(100.0, 0.0), Point(200.0, 0.0), Point(200.0, 100.0), Point(100.0, 100.0), Point(100.0, 0.0)))
        val output = TerritoryMapGeometryPreprocessor.process(listOf(a, b), emptyList()) { false }!!
        val adjustedA = output.polygonsByTerritory.getValue(1).first().points
        assertEquals(105.0, adjustedA[1].x, 0.001)
    }
}
