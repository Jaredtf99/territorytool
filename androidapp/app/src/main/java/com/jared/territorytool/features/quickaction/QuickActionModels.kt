package com.jared.territorytool.features.quickaction

import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.TerritoryInUse
import com.jared.territorytool.shared.models.daysBetween
import java.time.Instant

/** Resultado que la pantalla quiere resolver (escaneo o selección). */
sealed interface QuickActionResolution {
    data class ForTerritory(val territory: Territory) : QuickActionResolution
    data class ForPerson(val person: Person) : QuickActionResolution

    val id: String
        get() = when (this) {
            is ForTerritory -> "territory-${territory.id}"
            is ForPerson -> "person-${person.id}"
        }
}

/** Resultado del buscador unificado, ya ordenado por score en el backend. */
data class QuickSearchHit(
    val kind: Kind,
    val score: Double = 0.0,
    val territory: Territory? = null,
    val person: Person? = null,
) {
    enum class Kind { Territory, Person }

    val id: String
        get() = when (kind) {
            Kind.Territory -> "t-${territory?.id ?: -1}"
            Kind.Person -> "p-${person?.id ?: -1}"
        }

    val resolution: QuickActionResolution?
        get() = when (kind) {
            Kind.Territory -> territory?.let { QuickActionResolution.ForTerritory(it) }
            Kind.Person -> person?.let { QuickActionResolution.ForPerson(it) }
        }
}

val Territory.isAssigned: Boolean get() = personName != null

fun Territory.daysAssigned(now: Instant = Instant.now()): Int? {
    if (!isAssigned) return null
    val given = givenDateUtc ?: return null
    return daysBetween(given, now).coerceAtLeast(0)
}

fun Territory.daysFree(now: Instant = Instant.now()): Int? {
    if (isAssigned) return null
    val picked = lastPickedDateUtc ?: return null
    return daysBetween(picked, now).coerceAtLeast(0)
}

val Person.primaryActiveTerritory: TerritoryInUse? get() = territoriesInUse?.firstOrNull()
val Person.activeTerritoryCount: Int get() = territoriesInUse?.size ?: 0
val Person.hasActiveTerritory: Boolean get() = activeTerritoryCount > 0
val Person.maxDaysHeld: Int? get() = territoriesInUse?.maxOfOrNull { it.daysHeld() }

fun TerritoryInUse.daysHeld(now: Instant = Instant.now()): Int = daysBetween(givenDate, now).coerceAtLeast(0)

fun TerritoryInUse.asTerritory(personName: String) = Territory(
    id = territoryId, code = territoryCode, name = territoryName, mapUrl = "", imgUrl = null,
    personName = personName, givenDateUtc = givenDate, lastPickedDateUtc = null, mapGeometry = null,
)
