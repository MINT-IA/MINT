package ch.mint.coach

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!allowsRuntimeArgsChannel()) return

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ch.mint.app/runtime_args"
        ).setMethodCallHandler { call, result ->
            if (call.method == "launchArguments") {
                result.success(launchArguments())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun allowsRuntimeArgsChannel(): Boolean {
        return BuildConfig.ENABLE_RUNTIME_ARGS_CHANNEL
    }

    private fun launchArguments(): List<String> {
        val extras = intent?.extras ?: return emptyList()
        return extras.keySet().mapNotNull { key ->
            extras.get(key)?.toString()?.let { value -> "$key=$value" }
        }
    }
}
