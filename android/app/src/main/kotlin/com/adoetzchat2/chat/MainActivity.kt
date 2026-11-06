package com.adoetzchat2.chat

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.adoetzchat2.chat/native_bridge"
        private const val KEYSTORE_ALIAS = "com.adoetzchat2.chat.master_key"
        private const val PREFS_NAME = "adoetz_vault_keystore_prefs"
        private const val PREF_WRAPPED_PASSPHRASE = "wrapped_sqlcipher_passphrase_v2"
        private const val PREF_IV = "wrapped_sqlcipher_iv_v2"
        private const val CALL_CHANNEL_ID = "com.adoetzchat2.chat.calls"
        private const val MSG_CHANNEL_ID = "com.adoetzchat2.chat.messages"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getOrCreateVaultPassphrase" -> {
                            result.success(getOrCreateVaultPassphrase())
                        }
                        "rotateVaultPassphrase" -> {
                            result.success(rotateVaultPassphrase())
                        }
                        "setFlagSecure" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            result.success(true)
                        }
                        "showIncomingCallNotification" -> {
                            val callId = call.argument<String>("callId") ?: ""
                            val callerName = call.argument<String>("callerName") ?: "Kontak"
                            val callerUsername = call.argument<String>("callerUsername") ?: ""
                            val isVideo = call.argument<Boolean>("isVideo") ?: false
                            val expiresAtMs = call.argument<Number>("expiresAtMs")?.toLong()
                                ?: (System.currentTimeMillis() + 40_000L)
                            showIncomingCallNotification(
                                callId = callId,
                                callerName = callerName,
                                callerUsername = callerUsername,
                                isVideo = isVideo,
                                expiresAtMs = expiresAtMs
                            )
                            result.success(true)
                        }
                        "cancelCallNotification" -> {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            nm.cancel(9001)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("NATIVE_BRIDGE_ERR", e.message, null)
                }
            }
    }

    private fun getOrCreateMasterKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getEntry(KEYSTORE_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) {
            return existing.secretKey
        }
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )
        val spec = KeyGenParameterSpec.Builder(
            KEYSTORE_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    private fun getOrCreateVaultPassphrase(): String {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val wrappedB64 = prefs.getString(PREF_WRAPPED_PASSPHRASE, null)
        val ivB64 = prefs.getString(PREF_IV, null)
        val masterKey = getOrCreateMasterKey()

        if (wrappedB64 != null && ivB64 != null) {
            return try {
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                val iv = Base64.decode(ivB64, Base64.NO_WRAP)
                val wrapped = Base64.decode(wrappedB64, Base64.NO_WRAP)
                cipher.init(Cipher.DECRYPT_MODE, masterKey, GCMParameterSpec(128, iv))
                val rawPassphrase = cipher.doFinal(wrapped)
                Base64.encodeToString(rawPassphrase, Base64.NO_WRAP)
            } catch (_: Exception) {
                rotateVaultPassphrase()
            }
        }
        return rotateVaultPassphrase()
    }

    private fun rotateVaultPassphrase(): String {
        val raw = ByteArray(32)
        SecureRandom().nextBytes(raw)
        val masterKey = getOrCreateMasterKey()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, masterKey)
        val wrapped = cipher.doFinal(raw)
        val iv = cipher.iv

        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(PREF_WRAPPED_PASSPHRASE, Base64.encodeToString(wrapped, Base64.NO_WRAP))
            .putString(PREF_IV, Base64.encodeToString(iv, Base64.NO_WRAP))
            .apply()

        return Base64.encodeToString(raw, Base64.NO_WRAP)
    }

    private fun ensureNotificationChannels() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val callChannel = NotificationChannel(
            CALL_CHANNEL_ID,
            "Panggilan Suara & Video E2EE",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifikasi panggilan masuk terenkripsi end-to-end"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val msgChannel = NotificationChannel(
            MSG_CHANNEL_ID,
            "Pesan Terenkripsi E2EE",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifikasi pesan baru Adoetz Chat 2"
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        nm.createNotificationChannel(callChannel)
        nm.createNotificationChannel(msgChannel)
    }

    private fun showIncomingCallNotification(
        callId: String,
        callerName: String,
        callerUsername: String,
        isVideo: Boolean,
        expiresAtMs: Long
    ) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val now = System.currentTimeMillis()
        // ERR-06: If FCM wakeup arrives after TTL (40s), show Missed Call only, never ring!
        if (now > expiresAtMs) {
            val missedBuilder = Notification.Builder(this, MSG_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.sym_call_missed)
                .setContentTitle("Panggilan Tak Terjawab")
                .setContentText("$callerName (@$callerUsername)")
                .setAutoCancel(true)
            nm.notify(9002, missedBuilder.build())
            return
        }

        val fullScreenIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("adoetzchat2://call/$callId"),
            this,
            MainActivity::class.java
        ).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val fullScreenPending = PendingIntent.getActivity(
            this,
            100,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val declineIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("adoetzchat2://call/$callId?action=decline"),
            this,
            MainActivity::class.java
        )
        val declinePending = PendingIntent.getActivity(
            this,
            101,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val acceptIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("adoetzchat2://call/$callId?action=accept"),
            this,
            MainActivity::class.java
        )
        val acceptPending = PendingIntent.getActivity(
            this,
            102,
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = Notification.Builder(this, CALL_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(callerName)
            .setContentText(if (isVideo) "Panggilan Video Masuk E2EE..." else "Panggilan Suara Masuk E2EE...")
            .setCategory(Notification.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPending, true)
            .setOngoing(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val callerPerson = Person.Builder()
                .setName("$callerName (@$callerUsername)")
                .setImportant(true)
                .build()
            builder.style = Notification.CallStyle.forIncomingCall(
                callerPerson,
                declinePending,
                acceptPending
            ).setIsVideo(isVideo)
        }

        nm.notify(9001, builder.build())
    }
}
