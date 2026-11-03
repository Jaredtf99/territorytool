package com.jared.territorytool.shared.models

import java.time.Instant

data class Person(
    val id: Int,
    val name: String,
    val enabled: Boolean,
    val territoriesInUse: List<TerritoryInUse>?,
)

data class TerritoryInUse(
    val territoryId: Int,
    val territoryName: String,
    val territoryCode: String,
    val givenDate: Instant,
)

data class Transaction(
    val id: Int,
    val personId: Int,
    val givenDateUtc: Instant,
    val pickedDateUtc: Instant?,
    val givenBy: String?,
    val pickedBy: String?,
    val territoryId: Int,
    val territoryName: String,
    val personName: String,
    /** `null` cuando el origen no lo trae; al editar no se envía para no pisar el valor real. */
    val deliveryFormat: DeliveryFormat? = null,
)

data class User(val id: String, val userName: String, val role: UserRole)

enum class UserRole(val raw: String) {
    SuperAdmin("SUPERADMIN"), Admin("ADMIN"), User("USER");

    companion object {
        fun from(raw: String?): UserRole? = entries.firstOrNull { it.raw == raw?.uppercase() }
    }
}

data class ActionLog(
    val id: String,
    val type: ActionType,
    val dateUtc: Instant,
    val userName: String?,
    val message: String?,
    val successful: Boolean,
)

enum class ActionType(val code: Int) {
    Unknown(0), AddTerritory(1), EditTerritory(2), DeleteTerritory(3), AddUser(4), DeleteUser(5),
    ChangeUserPassword(6), EditUser(7), AddPerson(8), EditPerson(9), DeletePerson(10),
    GiveTerritory(11), PickTerritory(12), RefreshTerritoryImage(13), EditTransaction(14), DeleteTransaction(15);

    companion object {
        fun from(code: Int?): ActionType = entries.firstOrNull { it.code == code } ?: Unknown
    }
}

data class PaginatedResponse<T>(val data: List<T>, val currentPage: Int?, val lastPage: Int?, val total: Int?)

enum class UndoHandleKind { Domain, User }

data class UndoHandle(val id: String, val expiresAt: Instant, val kind: UndoHandleKind) {
    val toastDurationMillis: Long
        get() = maxOf(500L, expiresAt.toEpochMilli() - System.currentTimeMillis())
}

data class UndoableMutationResponse(val undoId: String, val expiresAt: Instant) {
    fun handle(kind: UndoHandleKind) = UndoHandle(undoId, expiresAt, kind)
}
