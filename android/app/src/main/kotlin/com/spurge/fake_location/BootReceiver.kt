package com.spurge.fake_location

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Resumes the mock location service after a reboot or app update if it was running before. */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in RESUME_ACTIONS || !ConfigStore.isEnabled(context)) return
        try {
            MockLocationService.start(context)
        } catch (e: Exception) {
            Log.e(TAG, "Could not resume mock location service", e)
        }
    }

    companion object {
        private const val TAG = "BootReceiver"
        private val RESUME_ACTIONS = setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)
    }
}
