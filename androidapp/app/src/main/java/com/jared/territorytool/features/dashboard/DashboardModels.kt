package com.jared.territorytool.features.dashboard

import androidx.annotation.StringRes
import com.jared.territorytool.R
import com.jared.territorytool.core.network.InstantSerializer
import com.jared.territorytool.shared.models.DeliveryFormat
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.TerritoryMapGeometry
import com.jared.territorytool.shared.models.Transaction
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.Instant
import java.time.LocalDate

object LocalDateSerializer : KSerializer<LocalDate> {
    override val descriptor = PrimitiveSerialDescriptor("LocalDate", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): LocalDate = LocalDate.parse(decoder.decodeString().take(10))
    override fun serialize(encoder: Encoder, value: LocalDate) = encoder.encodeString(value.toString())
}

@Serializable
data class DashboardSnapshot(
    @Serializable(InstantSerializer::class) val generatedAt: Instant? = null,
    val totals: DashboardTotals,
    val priority: DashboardPriority? = null,
    val activity: List<DashboardDailyActivity> = emptyList(),
    val weeklyEvents: List<DashboardMovement> = emptyList(),
    val recentEvents: List<DashboardMovement> = emptyList(),
    val hasMoreRecentEvents: Boolean = false,
    val attentionTerritories: List<DashboardAttentionTerritory> = emptyList(),
)

@Serializable
data class DashboardTotals(val total: Int = 0, val free: Int = 0, val inUse: Int = 0, val givenThisWeek: Int = 0)

@Serializable
data class DashboardPriority(
    val territoryId: Int,
    val code: String,
    val name: String,
    val personId: Int = 0,
    val personName: String,
    @Serializable(InstantSerializer::class) val givenAt: Instant,
    val mapUrl: String = "",
    val imagePath: String? = null,
    val mapGeometry: TerritoryMapGeometry? = null,
) {
    val territory: Territory
        get() = Territory(
            id = territoryId, code = code, name = name, mapUrl = mapUrl, imgUrl = null,
            personName = personName, givenDateUtc = givenAt, lastPickedDateUtc = null, mapGeometry = mapGeometry,
        )
}

@Serializable
data class DashboardDailyActivity(
    @Serializable(LocalDateSerializer::class) val date: LocalDate,
    val givenCount: Int = 0,
    val returnedCount: Int = 0,
)

@Serializable
enum class DashboardMovementType {
    @SerialName("given") Given,
    @SerialName("returned") Returned,
}

@Serializable
data class DashboardMovement(
    val transactionId: Int,
    val eventType: DashboardMovementType,
    @Serializable(InstantSerializer::class) val eventDate: Instant,
    val territoryId: Int,
    val territoryCode: String,
    val territoryName: String,
    val personId: Int = 0,
    val personName: String = "",
    @Serializable(InstantSerializer::class) val givenAt: Instant,
    @Serializable(InstantSerializer::class) val pickedAt: Instant? = null,
    val actorName: String = "",
    val deliveryFormat: DeliveryFormat? = null,
) {
    val id: String get() = "$transactionId-${eventType.name}"

    val transaction: Transaction
        get() = Transaction(
            id = transactionId, personId = personId, givenDateUtc = givenAt, pickedDateUtc = pickedAt,
            givenBy = if (eventType == DashboardMovementType.Given) actorName else null,
            pickedBy = if (eventType == DashboardMovementType.Returned) actorName else null,
            territoryId = territoryId, territoryName = territoryName, personName = personName,
            deliveryFormat = deliveryFormat,
        )

    val transactionEvent: TransactionEvent
        get() = TransactionEvent(
            txnId = transactionId,
            type = if (eventType == DashboardMovementType.Given) TransactionEvent.EventType.Given else TransactionEvent.EventType.Returned,
            date = eventDate,
            transaction = transaction,
        )
}

@Serializable
data class MovementHistoryPage(
    val data: List<DashboardMovement> = emptyList(),
    @SerialName("current_page") val currentPage: Int? = null,
    @SerialName("last_page") val lastPage: Int? = null,
    val total: Int? = null,
)

enum class MovementHistoryFilter(val raw: String, @StringRes val title: Int) {
    All("all", R.string.movements_filter_all),
    Given("given", R.string.movements_filter_given),
    Returned("returned", R.string.movements_filter_returned),
}

enum class MovementHistorySort(@StringRes val title: Int) {
    Newest(R.string.movements_sort_newest),
    Oldest(R.string.movements_sort_oldest);

    val ascending: Boolean get() = this == Oldest
}

@Serializable
data class DashboardMapBounds(val south: Double, val west: Double, val north: Double, val east: Double)

@Serializable
data class DashboardAttentionTerritory(
    val territoryId: Int,
    val code: String,
    val name: String,
    val personName: String = "",
    @Serializable(InstantSerializer::class) val givenAt: Instant,
    val mapBounds: DashboardMapBounds? = null,
)

data class TransactionEvent(
    val txnId: Int,
    val type: EventType,
    val date: Instant,
    val transaction: Transaction,
) {
    enum class EventType { Given, Returned }

    val id: String get() = "${txnId}_$type"
}
