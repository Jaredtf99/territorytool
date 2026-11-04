package com.jared.territorytool.shared.models

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

data class Territory(
    val id: Int,
    val code: String,
    val name: String,
    val mapUrl: String,
    val imgUrl: String?,
    val personName: String?,
    val givenDateUtc: Instant?,
    val lastPickedDateUtc: Instant?,
    val mapGeometry: TerritoryMapGeometry?,
    /** Formato de la entrega en curso; `null` si está libre. */
    val deliveryFormat: DeliveryFormat? = null,
    /** `true` = no aparece en las sugerencias para entregar; `null` si la fuente no lo trae. */
    val excludeFromSuggestions: Boolean? = null,
) {
    fun operationalStatus(attentionDays: Int = 90, now: Instant = Instant.now()): TerritoryOperationalStatus {
        if (personName == null) return TerritoryOperationalStatus.Available
        val given = givenDateUtc ?: return TerritoryOperationalStatus.Assigned(0)
        val days = daysBetween(given, now).coerceAtLeast(0)
        return if (days >= attentionDays) TerritoryOperationalStatus.Attention(days)
        else TerritoryOperationalStatus.Assigned(days)
    }
}

/** Días naturales transcurridos en la zona local (equivalente a `Calendar.dateComponents([.day])`). */
fun daysBetween(from: Instant, to: Instant = Instant.now()): Int {
    val zone = ZoneId.systemDefault()
    return ChronoUnit.DAYS.between(from.atZone(zone), to.atZone(zone)).toInt()
}

sealed interface TerritoryOperationalStatus {
    data object Available : TerritoryOperationalStatus
    data class Assigned(val days: Int) : TerritoryOperationalStatus
    data class Attention(val days: Int) : TerritoryOperationalStatus

    val isAssigned: Boolean get() = this !is Available
    val daysAssigned: Int?
        get() = when (this) {
            Available -> null
            is Assigned -> days
            is Attention -> days
        }
}

data class TerritoryDetail(
    val id: Int,
    val code: String,
    val name: String,
    val mapUrl: String,
    val imgUrl: String?,
    val personName: String?,
    val lastPickedDateUtc: Instant?,
    val givenDateUtc: Instant?,
    val pickedCount: Int,
    val lastUser: String?,
    val timelineItems: List<TimelineItem>,
    val mapGeometry: TerritoryMapGeometry?,
    val deliveryFormat: DeliveryFormat? = null,
    val excludeFromSuggestions: Boolean? = null,
)

/** Todo lo que necesita la pantalla de detalle, en una sola respuesta. */
data class TerritoryDetailBundle(
    val territory: TerritoryDetail,
    val stats: TerritoryStatistics,
    val transactions: List<Transaction>,
)

@Serializable
data class TerritoryMapGeometry(
    val version: Int = 1,
    val bounds: TerritoryMapBounds,
    val polygons: List<TerritoryMapFeature> = emptyList(),
    val polylines: List<TerritoryMapFeature> = emptyList(),
    val markers: List<TerritoryMapMarker> = emptyList(),
) {
    /** Huella FNV-1a estable de toda la geometría, para claves de caché de snapshots. */
    val snapshotFingerprint: String by lazy {
        var hash = -0x340d631b7bdddcdbL // 0xcbf29ce484222325
        val prime = 0x100000001b3L
        fun byte(b: Int) { hash = (hash xor (b.toLong() and 0xff)) * prime }
        fun long(v: Long) { for (i in 0 until 8) byte((v ushr (8 * i)).toInt()) }
        fun dbl(v: Double) = long(java.lang.Double.doubleToRawLongBits(v))
        fun str(s: String) { s.toByteArray().forEach { byte(it.toInt()) }; byte(0) }
        long(version.toLong())
        dbl(bounds.south); dbl(bounds.west); dbl(bounds.north); dbl(bounds.east)
        for (features in listOf(polygons, polylines)) {
            long(features.size.toLong())
            for (f in features) {
                str(f.id); long(f.coordinates.size.toLong())
                for (c in f.coordinates) { dbl(c.latitude); dbl(c.longitude) }
            }
        }
        long(markers.size.toLong())
        for (m in markers) { str(m.id); dbl(m.latitude); dbl(m.longitude) }
        java.lang.Long.toHexString(hash)
    }
}

@Serializable
data class TerritoryMapBounds(val south: Double, val west: Double, val north: Double, val east: Double)

@Serializable
data class TerritoryMapCoordinate(val latitude: Double, val longitude: Double)

@Serializable
data class TerritoryMapFeature(
    val id: String,
    val name: String? = null,
    val description: String? = null,
    val coordinates: List<TerritoryMapCoordinate> = emptyList(),
)

@Serializable
data class TerritoryMapMarker(
    val id: String,
    val title: String? = null,
    val description: String? = null,
    val latitude: Double,
    val longitude: Double,
)

data class TerritoryStatistics(
    val totalTerritories: Int,
    val usageRank: Int,
    val isHighUsage: Boolean,
    val isLowUsage: Boolean,
    val assignedTimePercentage: Double,
    val globalAverageAssignedTimePercentage: Double,
    val averageReassignmentTime: Double,
    val globalAverageReassignmentTime: Double,
    val averageHoldingTime: Double,
    val globalAverageHoldingTime: Double,
    val currentUnassignedTime: Double,
    val uniqueUsersCount: Int,
    val globalAverageUniqueUsersCount: Double,
)

data class TimelineItem(
    val id: Int,
    val description: String,
    val type: TimelineType,
    val date: Instant,
    val deliveryFormat: DeliveryFormat? = null,
)

enum class TimelineType(val raw: Int) { Picked(1), Gave(2), Edited(3), Added(4) }

/**
 * Territorios libres que merece la pena sugerir para entregar: sin los marcados como
 * "no sugerir", los nunca recogidos primero y luego los que llevan más tiempo libres.
 */
fun List<Territory>.giveSuggestions(limit: Int = 3): List<Territory> =
    filter { it.excludeFromSuggestions != true }
        .sortedWith(compareBy<Territory, Instant?>(nullsFirst()) { it.lastPickedDateUtc }.thenBy { it.id })
        .take(limit)
