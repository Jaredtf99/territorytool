package com.jared.territorytool.shared.models

import com.jared.territorytool.core.network.InstantSerializer
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate

/** Ficha de hermano devuelta por la RPC `get_person_detail` (JSON en camelCase). */
@Serializable
data class PersonDetail(
    val person: PersonDetailProfile,
    val summary: PersonDetailSummary,
    val current: List<PersonCurrentAssignment> = emptyList(),
    val activity: List<PersonMonthlyActivity> = emptyList(),
    val topTerritories: List<PersonTopTerritory> = emptyList(),
    val history: List<PersonAssignment> = emptyList(),
) {
    /** `Person` mínimo para reutilizar flujos que lo esperan (Acción rápida). */
    val asPerson: Person
        get() = Person(
            id = person.id,
            name = person.name,
            enabled = person.enabled,
            territoriesInUse = current.map { TerritoryInUse(it.territoryId, it.territoryName, it.territoryCode, it.givenAt) },
        )
}

@Serializable
data class PersonDetailProfile(
    val id: Int,
    val name: String,
    val enabled: Boolean = true,
    @Serializable(InstantSerializer::class) val createdAt: Instant? = null,
)

@Serializable
data class PersonDetailSummary(
    val totalAssignments: Int = 0,
    val activeAssignments: Int = 0,
    val completedAssignments: Int = 0,
    val uniqueTerritories: Int = 0,
    val virtualAssignments: Int = 0,
    val averageHoldingDays: Double? = null,
    val congregationAverageHoldingDays: Double? = null,
    val longestHoldingDays: Int? = null,
    @Serializable(InstantSerializer::class) val firstAssignmentAt: Instant? = null,
    @Serializable(InstantSerializer::class) val lastAssignmentAt: Instant? = null,
    @Serializable(InstantSerializer::class) val lastReturnAt: Instant? = null,
    val assignmentsLastYear: Int = 0,
    val activityRank: Int? = null,
    val activePersonsCount: Int = 0,
) {
    /** Última actividad (entrega o devolución, la más reciente). */
    val lastActivityAt: Instant? get() = listOfNotNull(lastAssignmentAt, lastReturnAt).maxOrNull()

    /** Días de diferencia con la media de la congregación (positivo = devuelve más tarde). */
    val holdingDelta: Int?
        get() {
            val mine = averageHoldingDays ?: return null
            val congregation = congregationAverageHoldingDays ?: return null
            if (completedAssignments == 0) return null
            return Math.round(mine - congregation).toInt()
        }
}

@Serializable
data class PersonCurrentAssignment(
    val transactionId: Int,
    val territoryId: Int,
    val territoryCode: String,
    val territoryName: String,
    @Serializable(InstantSerializer::class) val givenAt: Instant,
    val days: Int = 0,
    val deliveryFormat: DeliveryFormat = DeliveryFormat.Physical,
    val givenBy: String? = null,
    val mapGeometry: TerritoryMapGeometry? = null,
)

@Serializable
data class PersonMonthlyActivity(
    /** `YYYY-MM-DD`, primer día del mes en la zona horaria del dispositivo. */
    val month: String,
    val givenCount: Int = 0,
    val returnedCount: Int = 0,
) {
    val monthDate: LocalDate get() = runCatching { LocalDate.parse(month) }.getOrDefault(LocalDate.now())
}

@Serializable
data class PersonTopTerritory(
    val territoryId: Int,
    val territoryCode: String,
    val territoryName: String,
    val times: Int = 0,
    val totalDays: Int = 0,
    @Serializable(InstantSerializer::class) val lastGivenAt: Instant? = null,
)

@Serializable
data class PersonAssignment(
    val transactionId: Int,
    val territoryId: Int,
    val territoryCode: String,
    val territoryName: String,
    @Serializable(InstantSerializer::class) val givenAt: Instant,
    @Serializable(InstantSerializer::class) val pickedAt: Instant? = null,
    val days: Int = 0,
    val deliveryFormat: DeliveryFormat = DeliveryFormat.Physical,
    val givenBy: String? = null,
    val pickedBy: String? = null,
) {
    val isOngoing: Boolean get() = pickedAt == null
}
