package com.jared.territorytool.core.network

import java.util.concurrent.ConcurrentHashMap

/**
 * Caché en memoria de URLs firmadas de Supabase Storage (las firmas viven 3600 s; se
 * reutilizan ~50 min). Se vacía al cambiar de sesión o congregación.
 */
object SignedImageUrlCache {
    private data class Entry(val url: String, val expiresAt: Long)

    private const val LIFETIME_MS = 50 * 60 * 1000L
    private val entries = ConcurrentHashMap<String, Entry>()

    fun url(path: String, bucket: String, now: Long = System.currentTimeMillis()): String? {
        val key = "$bucket/$path"
        val entry = entries[key] ?: return null
        if (entry.expiresAt <= now) {
            entries.remove(key)
            return null
        }
        return entry.url
    }

    fun store(url: String, path: String, bucket: String, now: Long = System.currentTimeMillis()) {
        entries["$bucket/$path"] = Entry(url, now + LIFETIME_MS)
    }

    fun removeAll() = entries.clear()
}
