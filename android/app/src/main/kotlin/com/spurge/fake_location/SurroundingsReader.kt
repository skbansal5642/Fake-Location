package com.spurge.fake_location

import android.annotation.SuppressLint
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.SystemClock
import android.telephony.CellInfo
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoWcdma
import android.telephony.CellIdentityNr
import android.telephony.TelephonyManager
import java.util.concurrent.Executors

/** Reads the connected Wi-Fi, nearby access points and serving cells; none of these are affected by mock locations. */
class SurroundingsReader(context: Context) {
    private val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val telephony = context.applicationContext.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    private val executor = Executors.newSingleThreadExecutor()

    @SuppressLint("MissingPermission")
    fun read(): Surroundings {
        @Suppress("DEPRECATION")
        val info = runCatching { wifi.connectionInfo }.getOrNull()
        val ssid = normalizeSsid(info?.ssid)
        val connectedBssid = info?.bssid?.takeIf { it != UNKNOWN_BSSID }

        val nowMicros = SystemClock.elapsedRealtime() * 1000
        val scanned = runCatching { wifi.scanResults }.getOrNull().orEmpty()
            .filter { nowMicros - it.timestamp <= MAX_SCAN_AGE_MICROS }
            .mapNotNull { it.BSSID }

        val cells = runCatching { telephony.allCellInfo }.getOrNull().orEmpty()
            .filter { it.isRegistered }
            .mapNotNull(::cellKey)

        return Surroundings(ssid, (scanned + listOfNotNull(connectedBssid)).toSet(), cells.toSet())
    }

    /** Asks the system for fresh Wi-Fi scan and cell data; results show up in later [read] calls. */
    @SuppressLint("MissingPermission")
    fun requestRefresh() {
        @Suppress("DEPRECATION")
        runCatching { wifi.startScan() }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            runCatching {
                telephony.requestCellInfoUpdate(executor, object : TelephonyManager.CellInfoCallback() {
                    override fun onCellInfo(cellInfo: MutableList<CellInfo>) = Unit
                })
            }
        }
    }

    /** The SSID of the connected network, for showing in the UI. */
    fun currentSsid(): String? = read().ssid

    private fun cellKey(cell: CellInfo): String? = when (cell) {
        is CellInfoLte -> cell.cellIdentity.let { "lte:${it.ci}:${it.tac}" }
        is CellInfoGsm -> cell.cellIdentity.let { "gsm:${it.cid}:${it.lac}" }
        is CellInfoWcdma -> cell.cellIdentity.let { "wcdma:${it.cid}:${it.lac}" }
        else -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && cell is CellInfoNr) {
            (cell.cellIdentity as CellIdentityNr).let { "nr:${it.nci}:${it.tac}" }
        } else {
            null
        }
    }?.takeUnless { it.contains(":${Int.MAX_VALUE}") || it.contains(":${Long.MAX_VALUE}") }

    companion object {
        private const val UNKNOWN_SSID = "<unknown ssid>"
        private const val UNKNOWN_BSSID = "02:00:00:00:00:00"
        private const val MAX_SCAN_AGE_MICROS = 3 * 60 * 1_000_000L

        fun normalizeSsid(raw: String?): String? =
            raw?.removeSurrounding("\"")?.takeIf { it.isNotBlank() && it != UNKNOWN_SSID }
    }
}
