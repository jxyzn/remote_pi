package work.jacobmoura.remotepi

import android.view.View
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        findViewById<View>(android.R.id.content)?.let { root ->
            root.post { root.requestLayout() }
        }
    }
}
