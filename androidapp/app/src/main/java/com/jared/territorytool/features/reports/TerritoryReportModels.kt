package com.jared.territorytool.features.reports

import java.time.Instant

/** Un movimiento (entrega y, si existe, recogida) dentro del rango del informe. */
data class TerritoryReportEntry(
    val territoryId: Int,
    val code: String,
    val territoryName: String,
    val personName: String?,
    val givenAt: Instant?,
    val pickedAt: Instant?,
) {
    val id: String get() = "$territoryId-${givenAt?.epochSecond ?: 0}-${pickedAt?.epochSecond ?: 0}"
}

data class TerritoryReportResponse(val totalTerritories: Int, val entries: List<TerritoryReportEntry>)

/** Datos ya agrupados y resumidos, listos para pintar el PDF. */
class TerritoryReportData(
    entries: List<TerritoryReportEntry>,
    val totalTerritories: Int,
    val startDate: Instant,
    val endDate: Instant,
    val congregationName: String?,
) {
    data class TerritoryGroup(val code: String, val name: String, val entries: List<TerritoryReportEntry>)

    val groups: List<TerritoryGroup> = entries
        .groupBy { it.code }
        .map { (code, list) ->
            TerritoryGroup(code, list.first().territoryName, list.sortedBy { it.givenAt ?: Instant.MIN })
        }

    val territoriesWorked: Int get() = groups.size
    val territoriesNotWorked: Int get() = maxOf(0, totalTerritories - groups.size)
}
