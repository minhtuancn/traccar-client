package org.traccar.client

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.URI
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors
import javax.net.ssl.HttpsURLConnection

/**
 * User-initiated sideload updates only. No background installation, device-admin
 * operations, tracking changes, or permission grants. Android verifies the APK
 * again and owns the final installation confirmation.
 */
internal class UpdateInstaller(private val activity: FlutterActivity) {
    private val executor = Executors.newSingleThreadExecutor()
    private val directory = File(activity.cacheDir, "zalgps-updates")
    private var busy = false
    private var disposed = false
    private var prepared: Candidate? = null

    private data class Candidate(val version: String, val build: Long, val size: Long, val hash: String)

    companion object {
        private const val REPOSITORY = "minhtuancn/traccar-client"
        private const val CERTIFICATE = "1779fcc58da759bb71b1b65995039fa1cab6205361d53095005565e8dc52367f"
        private const val MAX_BYTES = 200L * 1024 * 1024
        private val VERSION = Regex("""\d+\.\d+\.\d+-beta\.\d+""")
        private val SHA = Regex("[a-f0-9]{64}")
        private val HOSTS = setOf("release-assets.githubusercontent.com", "objects.githubusercontent.com")
    }

    private fun integer(value: Any?): Long? = when (value) {
        is Int -> value.toLong()
        is Long -> value
        else -> null
    }

    private fun file(candidate: Candidate) = File(directory, "zalgps-${candidate.version}.apk")

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (disposed || busy) {
            result.error("busy", "Update operation is busy", null)
            return
        }
        when (call.method) {
            "prepare" -> {
                val version = call.argument<String>("version")
                val build = integer(call.argument<Any>("versionCode"))
                val size = integer(call.argument<Any>("size"))
                val hash = call.argument<String>("sha256")
                if (version == null || !VERSION.matches(version) ||
                    build == null || build !in 1..2100000000L ||
                    size == null || size !in 1..MAX_BYTES ||
                    hash == null || !SHA.matches(hash)) {
                    result.error("invalid_manifest", "Invalid update metadata", null)
                    return
                }
                val candidate = Candidate(version, build, size, hash)
                prepared = null
                run(result, work = {
                    checkInstalled(candidate)
                    check(directory.isDirectory || directory.mkdirs())
                    directory.listFiles()?.forEach { if (it.isFile) it.delete() }
                    val target = file(candidate)
                    try {
                        download(candidate, target)
                        verifyArchive(candidate, target)
                    } catch (error: Exception) {
                        target.delete()
                        throw error
                    }
                }, success = {
                    prepared = candidate
                    result.success(null)
                })
            }
            "installPrepared" -> {
                val candidate = prepared
                if (candidate == null) {
                    result.error("not_prepared", "No verified update", null)
                    return
                }
                if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                    result.error("install_permission", "Allow installation from this app in Android settings", null)
                    return
                }
                run(result, work = {
                    verifyArchive(candidate, file(candidate))
                }, success = {
                    val uri = FileProvider.getUriForFile(activity, activity.packageName + ".updates", file(candidate))
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    // Launch only in response to the user's explicit confirmation.
                    check(!activity.isFinishing && !activity.isDestroyed && activity.hasWindowFocus())
                    activity.startActivity(intent)
                    prepared = null
                    result.success(null)
                })
            }
            "discard" -> {
                prepared?.let { file(it).delete() }
                prepared = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun run(result: MethodChannel.Result, work: () -> Unit, success: () -> Unit) {
        busy = true
        executor.execute {
            val ok = try {
                work()
                true
            } catch (_: Exception) {
                false
            }
            activity.runOnUiThread {
                busy = false
                if (disposed) return@runOnUiThread
                if (!ok) {
                    result.error("verification_failed", "Update download or verification failed", null)
                } else {
                    try {
                        success()
                    } catch (_: Exception) {
                        result.error("installer_failed", "Could not open Android installer", null)
                    }
                }
            }
        }
    }

    private fun download(candidate: Candidate, target: File) {
        var url = URI("https://github.com/$REPOSITORY/releases/download/v${candidate.version}/${target.name}")
        val deadline = android.os.SystemClock.elapsedRealtime() + 300_000
        repeat(3) {
            check(android.os.SystemClock.elapsedRealtime() < deadline)
            val connection = URL(url.toString()).openConnection() as HttpsURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("Accept-Encoding", "identity")
            try {
                val status = connection.responseCode
                if (status in setOf(301, 302, 303, 307, 308)) {
                    val next = url.resolve(connection.getHeaderField("Location") ?: error("Missing redirect"))
                    check(next.scheme == "https" && next.userInfo == null && next.port == -1 && next.host in HOSTS)
                    url = next
                    return@repeat
                }
                check(status == 200)
                val contentLength = connection.getHeaderField("Content-Length")?.toLongOrNull()
                check(contentLength == null || contentLength == candidate.size)
                var total = 0L
                connection.inputStream.use { input ->
                    target.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            check(!Thread.currentThread().isInterrupted &&
                                android.os.SystemClock.elapsedRealtime() < deadline)
                            val count = input.read(buffer)
                            if (count == -1) break
                            total += count
                            check(total <= candidate.size)
                            output.write(buffer, 0, count)
                        }
                    }
                }
                check(total == candidate.size)
                return
            } finally {
                connection.disconnect()
            }
        }
        error("Too many redirects")
    }

    private fun hex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }

    @Suppress("DEPRECATION")
    private fun flags(): Int = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES
        else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun signer(info: PackageInfo): String {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        check(signatures != null && signatures.size == 1)
        return hex(MessageDigest.getInstance("SHA-256").digest(signatures.single().toByteArray()))
    }

    @Suppress("DEPRECATION")
    private fun build(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()

    private fun checkInstalled(candidate: Candidate) {
        @Suppress("DEPRECATION")
        val installed = activity.packageManager.getPackageInfo(activity.packageName, flags())
        check(activity.packageName == "org.traccar.client" && signer(installed) == CERTIFICATE &&
            candidate.build > build(installed))
    }

    private fun verifyArchive(candidate: Candidate, target: File) {
        checkInstalled(candidate)
        check(target.isFile && target.length() == candidate.size)
        val digest = MessageDigest.getInstance("SHA-256")
        target.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count == -1) break
                digest.update(buffer, 0, count)
            }
        }
        check(hex(digest.digest()) == candidate.hash)
        @Suppress("DEPRECATION")
        val archive = activity.packageManager.getPackageArchiveInfo(target.absolutePath, flags())
            ?: error("Invalid APK")
        check(archive.packageName == activity.packageName && signer(archive) == CERTIFICATE &&
            build(archive) == candidate.build && archive.versionName == candidate.version)
    }

    fun dispose() {
        disposed = true
        executor.shutdownNow()
    }
}
