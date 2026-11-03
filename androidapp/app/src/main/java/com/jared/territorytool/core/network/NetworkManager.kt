package com.jared.territorytool.core.network

import com.jared.territorytool.R
import com.jared.territorytool.core.Strings
import com.jared.territorytool.core.config.AppConfig
import com.jared.territorytool.features.dashboard.DashboardSnapshot
import com.jared.territorytool.features.dashboard.MovementHistoryFilter
import com.jared.territorytool.features.dashboard.MovementHistoryPage
import com.jared.territorytool.features.dashboard.MovementHistorySort
import com.jared.territorytool.features.quickaction.QuickSearchHit
import com.jared.territorytool.features.reports.TerritoryReportEntry
import com.jared.territorytool.features.reports.TerritoryReportResponse
import com.jared.territorytool.features.territories.TerritoryFilter
import com.jared.territorytool.shared.models.ActionLog
import com.jared.territorytool.shared.models.DeliveryFormat
import com.jared.territorytool.shared.models.ActionType
import com.jared.territorytool.shared.models.PaginatedResponse
import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.TerritoryDetail
import com.jared.territorytool.shared.models.TerritoryDetailBundle
import com.jared.territorytool.shared.models.TerritoryInUse
import com.jared.territorytool.shared.models.TerritoryMapGeometry
import com.jared.territorytool.shared.models.TerritoryStatistics
import com.jared.territorytool.shared.models.TimelineItem
import com.jared.territorytool.shared.models.TimelineType
import com.jared.territorytool.shared.models.Transaction
import com.jared.territorytool.shared.models.UndoableMutationResponse
import com.jared.territorytool.shared.models.User
import com.jared.territorytool.shared.models.UserRole
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import java.time.Instant
import java.util.UUID
import kotlin.math.ceil

/**
 * Servicio de datos de la app (equivale a `APIService`/`NetworkManager` de iOS).
 * Habla directamente con PostgREST, las RPC y las edge functions de Supabase.
 */
interface ApiService {
    suspend fun territoryExplorer(term: String?, filter: TerritoryFilter, attentionDays: Int): List<Territory>
    suspend fun getTerritories(term: String? = null, inUse: Boolean? = null, orderBy: Int? = null, ascending: Boolean = true): List<Territory>
    suspend fun searchQuickAction(term: String): List<QuickSearchHit>
    suspend fun getTerritory(id: Int): Territory
    suspend fun getTerritoryDetail(id: Int): TerritoryDetail
    suspend fun getTerritoryDetailBundle(id: Int): TerritoryDetailBundle
    suspend fun getDashboardSnapshot(weekStart: Instant, timeZone: String, attentionDays: Int): DashboardSnapshot
    suspend fun getTerritoryReport(start: Instant, end: Instant): TerritoryReportResponse
    suspend fun getMovementHistory(page: Int, pageSize: Int, search: String?, filter: MovementHistoryFilter, sort: MovementHistorySort): MovementHistoryPage
    suspend fun giveTerritoryUndoable(code: String, personName: String, date: Instant?): UndoableMutationResponse
    suspend fun pickTerritoryUndoable(code: String, date: Instant?): UndoableMutationResponse
    suspend fun getPersons(search: String? = null): List<Person>
    suspend fun getPersonsWithAssignments(search: String? = null): List<Person>
    suspend fun resolveTerritorySelector(value: String): Territory
    suspend fun addPersonUndoable(name: String): UndoableMutationResponse
    suspend fun updatePersonUndoable(id: Int, name: String, enabled: Boolean): UndoableMutationResponse
    suspend fun deletePersonUndoable(name: String): UndoableMutationResponse
    suspend fun addTerritoryUndoable(code: String, name: String, mapUrl: String): UndoableMutationResponse
    suspend fun updateTerritoryUndoable(id: Int, code: String, name: String, mapUrl: String): UndoableMutationResponse
    suspend fun deleteTerritory(id: Int)
    suspend fun deleteTerritoryUndoable(id: Int): UndoableMutationResponse
    suspend fun undoAction(id: String)
    suspend fun undoUserAction(id: String)
    suspend fun refreshTerritoryImage(id: Int)
    suspend fun syncTerritoryMap(id: Int)
    suspend fun getActionLogs(page: Int, pageSize: Int, sortField: String, sortOrder: String): PaginatedResponse<ActionLog>
    suspend fun getUsers(): List<User>
    suspend fun addUser(name: String, role: String, password: String)
    suspend fun addUserUndoable(name: String, role: String, password: String): UndoableMutationResponse
    suspend fun updateUser(id: String, name: String, role: String)
    suspend fun updateUserUndoable(id: String, name: String, role: String): UndoableMutationResponse
    suspend fun deleteUser(id: String)
    suspend fun deleteUserUndoable(id: String): UndoableMutationResponse
    suspend fun getDeactivatedUsers(): List<User>
    suspend fun reactivateUser(id: String)
    suspend fun changeUserPassword(id: String, newPassword: String)
    suspend fun deleteTransaction(id: Int)
    suspend fun deleteTransactionUndoable(id: Int): UndoableMutationResponse
    suspend fun updateTransactionUndoable(
        id: Int,
        personId: Int?,
        givenDate: Instant,
        pickedDate: Instant?,
        deliveryFormat: DeliveryFormat? = null,
    ): UndoableMutationResponse
}

class NetworkManager : ApiService {

    private companion object {
        const val TERRITORY_IMAGES_BUCKET = "territory-images"
    }

    // MARK: - Territorios

    override suspend fun territoryExplorer(term: String?, filter: TerritoryFilter, attentionDays: Int): List<Territory> {
        val rows = rpcRows(
            "search_territory_explorer",
            jsonBody("term" to term, "status" to filter.backendValue, "attention_days" to attentionDays, "take" to 1000),
        )
        return mapTerritories(rows)
    }

    override suspend fun getTerritories(term: String?, inUse: Boolean?, orderBy: Int?, ascending: Boolean): List<Territory> {
        val rows = rpcRows(
            "search_territories",
            jsonBody("term" to term, "only_free" to (inUse == false), "only_given" to (inUse == true), "take" to 1000),
        )
        val territories = mapTerritories(rows)
        val comparator: Comparator<Territory> = when (orderBy) {
            1 -> compareBy(String.CASE_INSENSITIVE_ORDER) { it.name }
            2 -> compareBy(String.CASE_INSENSITIVE_ORDER) { it.code }
            3 -> compareBy { it.givenDateUtc ?: Instant.MIN }
            else -> return territories
        }
        return territories.sortedWith(if (ascending) comparator else comparator.reversed())
    }

    override suspend fun searchQuickAction(term: String): List<QuickSearchHit> {
        // Buscador unificado: una RPC devuelve territorios y personas ya rankeados.
        val rows = rpcRows("search_quick_action", jsonBody("term" to term, "take" to 20))
        val territoryRows = rows.filter { it.str("kind") != "person" }.mapNotNull { it["data"].obj }
        val territories = mapTerritories(territoryRows).associateBy { it.id }
        return rows.mapNotNull { row ->
            val data = row["data"].obj ?: return@mapNotNull null
            val score = row.double("score") ?: 0.0
            if (row.str("kind") == "person") {
                QuickSearchHit(QuickSearchHit.Kind.Person, score, person = mapPerson(data, data["territoriesInUse"] ?: data["territories_in_use"]))
            } else {
                val territory = data.int("id")?.let { territories[it] } ?: return@mapNotNull null
                QuickSearchHit(QuickSearchHit.Kind.Territory, score, territory = territory)
            }
        }
    }

    override suspend fun getTerritory(id: Int): Territory =
        mapTerritories(listOf(territoryStateRow(id))).first()

    override suspend fun getTerritoryDetail(id: Int): TerritoryDetail = coroutineScope {
        val state = async { territoryStateRow(id) }
        val history = async { territoryHistoryRows(id) }
        territoryDetailPayload(state.await(), history.await(), id)
    }

    /** Detalle, estadísticas y transacciones solapando las tres consultas. */
    override suspend fun getTerritoryDetailBundle(id: Int): TerritoryDetailBundle = coroutineScope {
        val state = async { territoryStateRow(id) }
        val history = async { territoryHistoryRows(id) }
        val stats = async { rpcObject("get_territory_statistics", jsonBody("territory_id" to id)) }
        val historyRows = history.await()
        TerritoryDetailBundle(
            territory = territoryDetailPayload(state.await(), historyRows, id),
            stats = mapStatistics(stats.await()),
            transactions = mapTransactions(historyRows),
        )
    }

    override suspend fun getDashboardSnapshot(weekStart: Instant, timeZone: String, attentionDays: Int): DashboardSnapshot {
        val obj = rpcObject(
            "get_dashboard_snapshot",
            jsonBody("p_week_start" to Dates.iso(weekStart), "p_timezone" to timeZone, "p_attention_days" to attentionDays),
        )
        return decode(DashboardSnapshot.serializer(), obj)
    }

    override suspend fun getTerritoryReport(start: Instant, end: Instant): TerritoryReportResponse = coroutineScope {
        // Misma consulta que la edge function `generate-territory-report`: movimientos que se
        // solapan con el rango, incluidos los entregados antes del inicio que siguen sin
        // devolverse. RLS limita a la congregación activa.
        val s = Dates.iso(start)
        val e = Dates.iso(end)
        val rows = async {
            restRows(
                "/rest/v1/territory_details",
                listOf(
                    "select" to "territory_id,name,code,person_name,given_at,picked_at",
                    "given_at" to "lte.$e",
                    "or" to "(picked_at.is.null,picked_at.gte.$s)",
                    "order" to "code.asc,given_at.asc",
                ),
            )
        }
        val all = async { restRows("/rest/v1/territories", listOf("select" to "id")) }
        TerritoryReportResponse(
            totalTerritories = all.await().size,
            entries = rows.await().map { row ->
                TerritoryReportEntry(
                    territoryId = row.int("territory_id") ?: 0,
                    code = row.str("code") ?: "",
                    territoryName = row.str("name") ?: "",
                    personName = row.str("person_name"),
                    givenAt = row.date("given_at"),
                    pickedAt = row.date("picked_at"),
                )
            },
        )
    }

    override suspend fun getMovementHistory(
        page: Int,
        pageSize: Int,
        search: String?,
        filter: MovementHistoryFilter,
        sort: MovementHistorySort,
    ): MovementHistoryPage {
        val obj = rpcObject(
            "get_movement_history",
            jsonBody(
                "p_page" to page, "p_page_size" to pageSize, "p_search" to search,
                "p_event_type" to filter.raw, "p_sort_ascending" to sort.ascending,
            ),
        )
        return decode(MovementHistoryPage.serializer(), obj)
    }

    override suspend fun giveTerritoryUndoable(code: String, personName: String, date: Instant?) = undoable(
        rpcObject("give_territory_undoable", jsonBody("territory_code" to code, "person_name" to personName, "custom_date" to date)),
    )

    override suspend fun pickTerritoryUndoable(code: String, date: Instant?) = undoable(
        rpcObject("pick_territory_undoable", jsonBody("territory_code" to code, "custom_date" to date)),
    )

    // MARK: - Personas

    override suspend fun getPersons(search: String?): List<Person> {
        // Personas con sus transacciones abiertas embebidas (picked_at null).
        val query = mutableListOf(
            "select" to "id,name,enabled,territory_transactions(given_at,picked_at,territories(id,name,code))",
            "order" to "name.asc",
        )
        if (!search.isNullOrEmpty()) query += "name" to "ilike.*$search*"
        return restRows("/rest/v1/persons", query).map { row ->
            val inUse = (row["territory_transactions"].arr ?: JsonArray(emptyList()))
                .mapNotNull { it.obj }
                .filter { it["picked_at"].isNull() }
                .mapNotNull { tx ->
                    val territory = tx["territories"].obj
                    TerritoryInUse(
                        territoryId = territory?.int("id") ?: 0,
                        territoryName = territory?.str("name") ?: "",
                        territoryCode = territory?.str("code") ?: "",
                        givenDate = tx.date("given_at") ?: return@mapNotNull null,
                    )
                }
            Person(row.int("id") ?: 0, row.str("name") ?: "", row.bool("enabled") ?: true, inUse)
        }
    }

    override suspend fun getPersonsWithAssignments(search: String?): List<Person> =
        rpcRows("search_persons_with_assignments", jsonBody("term" to search, "take" to 1000))
            .map { mapPerson(it, it["territories_in_use"]) }

    override suspend fun resolveTerritorySelector(value: String): Territory {
        val rows = rpcRows("resolve_territory_selector", jsonBody("value" to value))
        return mapTerritories(rows).firstOrNull()
            ?: throw NetworkError.Server(Strings.get(R.string.quick_action_territory_not_found))
    }

    override suspend fun addPersonUndoable(name: String) =
        undoable(rpcObject("add_person_undoable", jsonBody("name" to name)))

    override suspend fun updatePersonUndoable(id: Int, name: String, enabled: Boolean) =
        undoable(rpcObject("update_person_undoable", jsonBody("person_id" to id, "name" to name, "enabled" to enabled)))

    override suspend fun deletePersonUndoable(name: String) =
        undoable(rpcObject("delete_person_undoable", jsonBody("name" to name)))

    // MARK: - Gestión de territorios

    override suspend fun addTerritoryUndoable(code: String, name: String, mapUrl: String) =
        undoable(rpcObject("add_territory_undoable", jsonBody("code" to code, "name" to name, "map_url" to mapUrl)))

    override suspend fun updateTerritoryUndoable(id: Int, code: String, name: String, mapUrl: String) = undoable(
        rpcObject("update_territory_undoable", jsonBody("territory_id" to id, "code" to code, "name" to name, "map_url" to mapUrl)),
    )

    override suspend fun deleteTerritory(id: Int) {
        rpcObject("delete_territory", jsonBody("territory_id" to id))
    }

    override suspend fun deleteTerritoryUndoable(id: Int) =
        undoable(rpcObject("delete_territory_undoable", jsonBody("territory_id" to id)))

    override suspend fun undoAction(id: String) {
        rpcObject("undo_action", jsonBody("p_undo_id" to id))
    }

    override suspend fun undoUserAction(id: String) {
        edgeFunction("admin-users", jsonBody("action" to "undo", "undoId" to id))
    }

    override suspend fun refreshTerritoryImage(id: Int) {
        edgeFunction("refresh-territory-image", jsonBody("territoryId" to id))
    }

    override suspend fun syncTerritoryMap(id: Int) {
        edgeFunction("refresh-territory-image", jsonBody("territoryId" to id, "geometryOnly" to true))
    }

    // MARK: - Registros

    override suspend fun getActionLogs(page: Int, pageSize: Int, sortField: String, sortOrder: String): PaginatedResponse<ActionLog> {
        val response = rpcObject(
            "get_action_logs",
            jsonBody("page_number" to page, "page_size" to pageSize, "sort_field" to sortField, "sort_order" to sortOrder),
        )
        val logs = (response["data"].arr ?: JsonArray(emptyList())).mapNotNull { it.obj }.mapNotNull { row ->
            ActionLog(
                id = UUID.randomUUID().toString(),
                type = ActionType.from(row.int("actionType") ?: row.int("ActionType")),
                dateUtc = row.date("dateUtc") ?: row.date("DateUtc") ?: return@mapNotNull null,
                userName = row.str("userName") ?: row.str("UserName"),
                message = row.str("message") ?: row.str("Message"),
                successful = row.bool("successful") ?: row.bool("Successful") ?: false,
            )
        }
        val total = response.int("totalCount") ?: logs.size
        val lastPage = maxOf(1, ceil(total.toDouble() / maxOf(pageSize, 1)).toInt())
        return PaginatedResponse(logs, page, lastPage, total)
    }

    // MARK: - Usuarios

    override suspend fun getUsers(): List<User> = mapUsers(edgeFunction("admin-users", jsonBody("action" to "list")))

    override suspend fun addUser(name: String, role: String, password: String) {
        edgeFunction("admin-users", jsonBody("action" to "create", "username" to name, "role" to role, "password" to password))
    }

    override suspend fun addUserUndoable(name: String, role: String, password: String) = undoable(
        edgeFunction("admin-users", jsonBody("action" to "create-undoable", "username" to name, "role" to role, "password" to password)).obj,
    )

    override suspend fun updateUser(id: String, name: String, role: String) {
        edgeFunction("admin-users", jsonBody("action" to "update", "userId" to id, "username" to name, "role" to role))
    }

    override suspend fun updateUserUndoable(id: String, name: String, role: String) = undoable(
        edgeFunction("admin-users", jsonBody("action" to "update-undoable", "userId" to id, "username" to name, "role" to role)).obj,
    )

    override suspend fun deleteUser(id: String) {
        edgeFunction("admin-users", jsonBody("action" to "delete", "userId" to id))
    }

    override suspend fun deleteUserUndoable(id: String) =
        undoable(edgeFunction("admin-users", jsonBody("action" to "delete-undoable", "userId" to id)).obj)

    override suspend fun getDeactivatedUsers(): List<User> =
        mapUsers(edgeFunction("admin-users", jsonBody("action" to "list-deactivated")))

    override suspend fun reactivateUser(id: String) {
        edgeFunction("admin-users", jsonBody("action" to "reactivate", "userId" to id))
    }

    override suspend fun changeUserPassword(id: String, newPassword: String) {
        edgeFunction("admin-users", jsonBody("action" to "change-password", "userId" to id, "newPassword" to newPassword))
    }

    // MARK: - Transacciones

    override suspend fun deleteTransaction(id: Int) {
        rpcObject("delete_transaction", jsonBody("transaction_id" to id))
    }

    override suspend fun deleteTransactionUndoable(id: Int) =
        undoable(rpcObject("delete_transaction_undoable", jsonBody("transaction_id" to id)))

    override suspend fun updateTransactionUndoable(
        id: Int,
        personId: Int?,
        givenDate: Instant,
        pickedDate: Instant?,
        deliveryFormat: DeliveryFormat?,
    ) = undoable(
        rpcObject(
            "update_transaction_undoable",
            jsonBody(
                "transaction_id" to id,
                "person_id" to personId,
                "given_at" to givenDate,
                "picked_at" to pickedDate,
                // `null` conserva el formato guardado.
                "delivery_format" to deliveryFormat?.raw,
            ),
        ),
    )

    // MARK: - Transporte

    private suspend fun restRows(path: String, query: List<Pair<String, String>>): List<JsonObject> =
        requestJson(path, "GET", query).arr?.mapNotNull { it.obj } ?: emptyList()

    private suspend fun rpcRows(name: String, body: JsonObject): List<JsonObject> =
        requestJson("/rest/v1/rpc/$name", "POST", body = body).arr?.mapNotNull { it.obj } ?: emptyList()

    private suspend fun rpcObject(name: String, body: JsonObject): JsonObject =
        requestJson("/rest/v1/rpc/$name", "POST", body = body).obj ?: JsonObject(emptyMap())

    private suspend fun edgeFunction(name: String, body: JsonObject): JsonElement =
        requestJson("/functions/v1/$name", "POST", body = body)

    private suspend fun requestJson(
        path: String,
        method: String,
        query: List<Pair<String, String>> = emptyList(),
        body: JsonElement? = null,
    ): JsonElement = NetworkTransport.json(NetworkTransport.makeRequest(path, method, query, body))

    private fun <T> decode(serializer: kotlinx.serialization.KSerializer<T>, element: JsonElement): T =
        runCatching { SupabaseJson.decodeFromJsonElement(serializer, element) }.getOrElse {
            android.util.Log.e("NetworkManager", "Decoding error", it)
            throw NetworkError.Decoding()
        }

    private fun undoable(obj: JsonObject?): UndoableMutationResponse {
        val id = obj?.str("undoId")
        val expires = obj?.date("expiresAt")
        if (id == null || expires == null) throw NetworkError.Decoding()
        return UndoableMutationResponse(id, expires)
    }

    // MARK: - Mapeos

    private suspend fun territoryStateRow(id: Int): JsonObject =
        restRows("/rest/v1/territory_current_state", listOf("select" to "*", "id" to "eq.$id")).firstOrNull()
            ?: throw NetworkError.InvalidResponse()

    private suspend fun territoryHistoryRows(id: Int): List<JsonObject> = restRows(
        "/rest/v1/territory_details",
        listOf("select" to "*", "territory_id" to "eq.$id", "order" to "given_at.desc"),
    )

    private suspend fun territoryDetailPayload(state: JsonObject, history: List<JsonObject>, id: Int): TerritoryDetail {
        val territory = mapTerritories(listOf(state)).firstOrNull()
        val timeline = history.flatMap { row ->
            val transactionId = row.int("transaction_id") ?: return@flatMap emptyList()
            val person = row.str("person_name") ?: ""
            val format = DeliveryFormat.from(row.str("delivery_format"))
            buildList {
                row.date("given_at")?.let { add(TimelineItem(transactionId * 10 + 2, "Entregado a $person", TimelineType.Gave, it, format)) }
                row.date("picked_at")?.let { add(TimelineItem(transactionId * 10 + 1, "Recogido de $person", TimelineType.Picked, it, format)) }
            }
        }
        return TerritoryDetail(
            id = territory?.id ?: id,
            code = territory?.code ?: "",
            name = territory?.name ?: "",
            mapUrl = territory?.mapUrl ?: "",
            imgUrl = territory?.imgUrl,
            personName = territory?.personName,
            lastPickedDateUtc = territory?.lastPickedDateUtc,
            givenDateUtc = territory?.givenDateUtc,
            pickedCount = history.count { !it["picked_at"].isNull() },
            lastUser = history.firstOrNull()?.str("person_name"),
            timelineItems = timeline,
            mapGeometry = territory?.mapGeometry,
            deliveryFormat = territory?.deliveryFormat,
        )
    }

    private suspend fun mapTerritories(rows: List<JsonObject>): List<Territory> {
        // Sólo se firman las imágenes de territorios sin geometría: con geometría la UI
        // dibuja el polígono y nunca mira `imgUrl`.
        val paths = rows.mapNotNull { row ->
            row.str("image_path")?.takeIf { row["map_geometry"].isNull() && it.isNotEmpty() }
        }
        val signed = signedImageUrls(paths)
        return rows.mapNotNull { row ->
            Territory(
                id = row.int("id") ?: return@mapNotNull null,
                code = row.str("code") ?: "",
                name = row.str("name") ?: "",
                mapUrl = row.str("map_url") ?: "",
                imgUrl = row.str("image_path")?.let { signed[it] },
                personName = row.str("person_name"),
                givenDateUtc = row.date("given_at"),
                lastPickedDateUtc = row.date("last_picked_at"),
                mapGeometry = row["map_geometry"]?.takeUnless { it.isNull() }?.let { geometry ->
                    runCatching { SupabaseJson.decodeFromJsonElement(TerritoryMapGeometry.serializer(), geometry) }.getOrNull()
                },
                deliveryFormat = if (row["person_id"].isNull()) null else DeliveryFormat.from(row.str("delivery_format")),
            )
        }
    }

    private fun mapPerson(row: JsonObject, inUse: JsonElement?): Person = Person(
        id = row.int("id") ?: 0,
        name = row.str("name") ?: "",
        enabled = row.bool("enabled") ?: true,
        territoriesInUse = inUse.arr?.mapNotNull { it.obj }?.mapNotNull { t ->
            TerritoryInUse(
                territoryId = t.int("territoryId") ?: t.int("territory_id") ?: 0,
                territoryName = t.str("territoryName") ?: t.str("territory_name") ?: "",
                territoryCode = t.str("territoryCode") ?: t.str("territory_code") ?: "",
                givenDate = t.date("givenDate") ?: t.date("given_date") ?: t.date("given_at") ?: return@mapNotNull null,
            )
        },
    )

    private fun mapUsers(element: JsonElement): List<User> = element.arr?.mapNotNull { it.obj }?.map { row ->
        User(row.str("id") ?: "", row.str("username") ?: "", UserRole.from(row.str("role")) ?: UserRole.User)
    } ?: emptyList()

    private fun mapTransactions(rows: List<JsonObject>): List<Transaction> = rows.mapNotNull { row ->
        Transaction(
            id = row.int("transaction_id") ?: return@mapNotNull null,
            personId = row.int("person_id") ?: 0,
            givenDateUtc = row.date("given_at") ?: return@mapNotNull null,
            pickedDateUtc = row.date("picked_at"),
            givenBy = row.str("given_by_username"),
            pickedBy = row.str("picked_by_username"),
            territoryId = row.int("territory_id") ?: 0,
            territoryName = row.str("territory_name") ?: row.str("name") ?: "",
            personName = row.str("person_name") ?: "",
            deliveryFormat = DeliveryFormat.from(row.str("delivery_format")),
        )
    }

    /** Coacciona nulos numéricos a 0 (p. ej. `averageHoldingTime` sin asignaciones cerradas). */
    private fun mapStatistics(row: JsonObject) = TerritoryStatistics(
        totalTerritories = row.int("totalTerritories") ?: 0,
        usageRank = row.int("usageRank") ?: 0,
        isHighUsage = row.bool("isHighUsage") ?: false,
        isLowUsage = row.bool("isLowUsage") ?: false,
        assignedTimePercentage = row.double("assignedTimePercentage") ?: 0.0,
        globalAverageAssignedTimePercentage = row.double("globalAverageAssignedTimePercentage") ?: 0.0,
        averageReassignmentTime = row.double("averageReassignmentTime") ?: 0.0,
        globalAverageReassignmentTime = row.double("globalAverageReassignmentTime") ?: 0.0,
        averageHoldingTime = row.double("averageHoldingTime") ?: 0.0,
        globalAverageHoldingTime = row.double("globalAverageHoldingTime") ?: 0.0,
        currentUnassignedTime = row.double("currentUnassignedTime") ?: 0.0,
        uniqueUsersCount = row.int("uniqueUsersCount") ?: 0,
        globalAverageUniqueUsersCount = row.double("globalAverageUniqueUsersCount") ?: 0.0,
    )

    /**
     * Firma en una sola petición todas las rutas que no estén en caché. El endpoint de lote
     * puede devolver 200 con entradas fallidas: cada una se comprueba por separado.
     */
    private suspend fun signedImageUrls(paths: List<String>): Map<String, String> {
        val result = mutableMapOf<String, String>()
        val pending = mutableListOf<String>()
        for (path in paths.toSet()) {
            val cached = SignedImageUrlCache.url(path, TERRITORY_IMAGES_BUCKET)
            if (cached != null) result[path] = cached else pending += path
        }
        if (pending.isEmpty()) return result

        val response = runCatching {
            requestJson(
                "/storage/v1/object/sign/$TERRITORY_IMAGES_BUCKET",
                "POST",
                body = jsonBody("expiresIn" to 3600, "paths" to pending),
            )
        }.getOrNull()
        response.arr?.mapNotNull { it.obj }?.forEach { entry ->
            if (!entry["error"].isNull()) return@forEach
            val path = entry.str("path") ?: return@forEach
            val signed = entry.str("signedURL") ?: entry.str("signedUrl") ?: return@forEach
            val absolute = absoluteStorageUrl(signed)
            result[path] = absolute
            SignedImageUrlCache.store(absolute, path, TERRITORY_IMAGES_BUCKET)
        }
        return result
    }

    private fun absoluteStorageUrl(signed: String): String {
        if (signed.startsWith("http")) return signed
        val relative = if (signed.startsWith("/storage/v1")) signed else "/storage/v1$signed"
        return AppConfig.SUPABASE_URL + relative
    }
}
