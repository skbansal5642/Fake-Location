package com.spurge.fake_location

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationManager
import android.location.provider.ProviderProperties
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * Foreground service that reports a mock location chosen by the configured mode:
 * a daily schedule, a fixed place, or rules that swap the location near certain places.
 */
class MockLocationService : Service() {

    private lateinit var locationManager: LocationManager
    private lateinit var fused: FusedLocationProviderClient
    private lateinit var surroundingsReader: SurroundingsReader
    private val handler = Handler(Looper.getMainLooper())
    private val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
    private val activeProviders = mutableListOf<String>()
    private val drift = Drift()

    private var config = MockConfig()
    private var ruleEngine: RuleEngine? = null
    private var ruleTarget: Place? = null
    private var lastRealFix: Fix? = null
    private var watchingRealLocation = false
    private var ticks = 0L
    private var lastStatus: String? = null

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        fused = LocationServices.getFusedLocationProviderClient(this)
        surroundingsReader = SurroundingsReader(this)
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            ConfigStore.setEnabled(this, false)
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            startInForeground(getString(R.string.mock_starting))
        } catch (e: Exception) {
            // Android may still refuse a foreground service started from the background.
            Log.e(TAG, "Could not enter foreground", e)
            stopSelf()
            return START_NOT_STICKY
        }
        config = ConfigStore.load(this)
        if (!config.isRunnable || !MockPermission.isGranted(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        // Restarting with a new configuration begins from a clean state.
        handler.removeCallbacks(tick)
        stopMocking()
        stopWatchingRealLocation()
        ruleEngine = if (config.mode == Mode.RULES) RuleEngine(config.rules) else null
        ruleTarget = null
        lastRealFix = null
        lastStatus = null
        ticks = 0
        if (config.mode == Mode.RULES) {
            watchRealLocation()
            surroundingsReader.requestRefresh()
        }
        isRunning = true
        handler.post(tick)
        return START_STICKY
    }

    private val tick = object : Runnable {
        override fun run() {
            if (config.mode == Mode.RULES) {
                if (ticks % SCAN_EVERY_TICKS == 0L) surroundingsReader.requestRefresh()
                if (ticks % EVALUATE_EVERY_TICKS == 0L) evaluateRules()
            }
            val target = when (config.mode) {
                Mode.SCHEDULE -> Schedule.current(config.slots)?.place
                Mode.FIXED -> config.fixed
                Mode.RULES -> ruleTarget
            }
            if (target == null) {
                stopMocking()
            } else if (!report(target)) {
                stopSelf()
                return
            }
            updateStatus(target)
            ticks++
            handler.postDelayed(this, TICK_MS)
        }
    }

    private fun evaluateRules() {
        val engine = ruleEngine ?: return
        val surroundings = runCatching { surroundingsReader.read() }.getOrDefault(Surroundings.NONE)
        val rule = engine.evaluate(SystemClock.elapsedRealtime(), lastRealFix, surroundings)
        ruleTarget = rule?.target
    }

    /** Pushes [place] (plus drift) to every provider; false if mock access was revoked. */
    @SuppressLint("MissingPermission")
    private fun report(place: Place): Boolean {
        if (!startMocking()) return false
        val (north, east) = drift.next(config.driftMeters)
        val (lat, lng) = Geo.offset(place.lat, place.lng, north, east)
        val accuracy = drift.nextAccuracy()
        return try {
            for (p in activeProviders) locationManager.setTestProviderLocation(p, buildLocation(p, lat, lng, accuracy))
            fused.setMockLocation(buildLocation("fused", lat, lng, accuracy))
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "Mock location permission revoked", e)
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun startMocking(): Boolean {
        if (activeProviders.isNotEmpty()) return true
        return try {
            for (p in providers) {
                runCatching { locationManager.removeTestProvider(p) }
                addTestProvider(p)
                locationManager.setTestProviderEnabled(p, true)
                activeProviders += p
            }
            fused.setMockMode(true)
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "Not selected as mock location app", e)
            stopMocking()
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopMocking() {
        if (activeProviders.isEmpty()) return
        for (p in activeProviders) runCatching { locationManager.removeTestProvider(p) }
        activeProviders.clear()
        runCatching { fused.setMockMode(false) }
        drift.reset()
    }

    private fun addTestProvider(p: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            locationManager.addTestProvider(
                p, false, false, false, false, true, true, true,
                ProviderProperties.POWER_USAGE_LOW, ProviderProperties.ACCURACY_FINE,
            )
        } else {
            @Suppress("DEPRECATION")
            locationManager.addTestProvider(p, false, false, false, false, true, true, true, 1, 1)
        }
    }

    private fun buildLocation(provider: String, lat: Double, lng: Double, accuracyM: Float) = Location(provider).apply {
        latitude = lat
        longitude = lng
        altitude = 0.0
        accuracy = accuracyM
        speed = 0f
        bearing = 0f
        time = System.currentTimeMillis()
        elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
    }

    private val realLocationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location = result.lastLocation ?: return
            if (location.isMockLocation()) return
            lastRealFix = Fix(location.latitude, location.longitude, location.accuracy, location.elapsedRealtimeNanos / 1_000_000)
        }
    }

    /** Requests real fixes for rule entry; mock fixes delivered while a rule is active are ignored. */
    @SuppressLint("MissingPermission")
    private fun watchRealLocation() {
        if (watchingRealLocation) return
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, REAL_LOCATION_INTERVAL_MS).build()
        try {
            fused.requestLocationUpdates(request, realLocationCallback, Looper.getMainLooper())
            watchingRealLocation = true
        } catch (e: SecurityException) {
            Log.e(TAG, "No location permission; only Wi-Fi rules can trigger", e)
        }
    }

    private fun stopWatchingRealLocation() {
        if (!watchingRealLocation) return
        fused.removeLocationUpdates(realLocationCallback)
        watchingRealLocation = false
    }

    private fun Location.isMockLocation(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) isMock else @Suppress("DEPRECATION") isFromMockProvider

    private fun updateStatus(target: Place?) {
        val status = when {
            target != null && ruleEngine?.isExitBlind == true -> getString(R.string.mock_at_exit_blind, target.name)
            target != null -> getString(R.string.mock_at, target.name)
            else -> getString(R.string.mock_watching, config.rules.size)
        }
        statusText = status
        if (status == lastStatus) return
        lastStatus = status
        notificationManager().notify(NOTIFICATION_ID, buildNotification(status))
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        stopMocking()
        stopWatchingRealLocation()
        isRunning = false
        statusText = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startInForeground(text: String) {
        val notification = buildNotification(text)
        // specialUse rather than location: the service only writes mock locations, and a
        // location-type service cannot be started from the background (e.g. at boot).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun notificationManager() = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager().createNotificationChannel(
                NotificationChannel(CHANNEL_ID, getString(R.string.channel_name), NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    private fun buildNotification(text: String): Notification {
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, MockLocationService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, getString(R.string.stop), stop).build())
            .build()
    }

    companion object {
        private const val TAG = "MockLocationService"
        private const val CHANNEL_ID = "mock_location"
        private const val NOTIFICATION_ID = 1
        private const val TICK_MS = 1000L
        private const val EVALUATE_EVERY_TICKS = 15L
        private const val SCAN_EVERY_TICKS = 30L
        private const val REAL_LOCATION_INTERVAL_MS = 10_000L
        const val ACTION_STOP = "com.spurge.fake_location.STOP"

        @Volatile
        var isRunning = false
            private set

        /** What the service is currently doing, for the UI. */
        @Volatile
        var statusText: String? = null
            private set

        fun start(context: Context) {
            ConfigStore.setEnabled(context, true)
            val intent = Intent(context, MockLocationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
            else context.startService(intent)
        }

        fun stop(context: Context) {
            ConfigStore.setEnabled(context, false)
            context.stopService(Intent(context, MockLocationService::class.java))
        }
    }
}
