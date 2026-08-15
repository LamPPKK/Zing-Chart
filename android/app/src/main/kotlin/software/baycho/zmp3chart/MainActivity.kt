package software.baycho.zmp3chart

import android.Manifest
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val platformChannel = "software.baycho.zmp3chart/platform"
    private val companionChannel = "software.baycho.zmp3chart/companion"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, platformChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "isTelevision") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                result.success(
                    uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION,
                )
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, companionChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "publishSnapshot") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                @Suppress("UNCHECKED_CAST")
                val values = call.arguments as? Map<String, Any?>
                if (values == null) {
                    result.error("invalid_snapshot", "Expected a snapshot map.", null)
                    return@setMethodCallHandler
                }
                CompanionStateStore.save(applicationContext, values)
                result.success(null)
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }
}
