package software.baycho.zmp3chart.watch

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable

class MainActivity : Activity(), DataClient.OnDataChangedListener {
    private lateinit var connection: TextView
    private lateinit var title: TextView
    private lateinit var artist: TextView
    private lateinit var progress: ProgressBar
    private lateinit var playPause: ImageButton
    private var playerState = PlayerState()
    private val handler = Handler(Looper.getMainLooper())
    private val progressTicker = object : Runnable {
        override fun run() {
            renderProgress()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.BLACK
        setContentView(buildSurface())
        readLatestState()
    }

    override fun onResume() {
        super.onResume()
        Wearable.getDataClient(this).addListener(this)
        handler.post(progressTicker)
    }

    override fun onPause() {
        Wearable.getDataClient(this).removeListener(this)
        handler.removeCallbacks(progressTicker)
        super.onPause()
    }

    override fun onDataChanged(events: DataEventBuffer) {
        events.forEach { event ->
            if (event.type == DataEvent.TYPE_CHANGED &&
                event.dataItem.uri.path == playerPath
            ) {
                render(DataMapItem.fromDataItem(event.dataItem).dataMap)
            }
        }
    }

    private fun readLatestState() {
        Wearable.getDataClient(this).dataItems
            .addOnSuccessListener { items ->
                try {
                    val item = items.firstOrNull { it.uri.path == playerPath }
                    if (item != null) render(DataMapItem.fromDataItem(item).dataMap)
                } finally {
                    items.release()
                }
            }
            .addOnFailureListener {
                connection.text = getString(R.string.watch_disconnected)
            }
    }

    private fun render(data: DataMap) = runOnUiThread {
        playerState = PlayerState(
            title = data.getString("title") ?: "#zingChart",
            artist = data.getString("artist") ?: getString(R.string.watch_open_phone),
            isPlaying = data.getBoolean("isPlaying", false),
            positionMs = data.getLong("positionMs", 0L),
            durationMs = data.getLong("durationMs", 0L),
            updatedAtMs = data.getLong("updatedAtMs", 0L),
        )
        connection.text = getString(R.string.watch_connected)
        title.text = playerState.title
        artist.text = playerState.artist
        playPause.setImageResource(
            if (playerState.isPlaying) R.drawable.ic_watch_pause else R.drawable.ic_watch_play,
        )
        playPause.contentDescription = getString(
            if (playerState.isPlaying) R.string.watch_pause else R.string.watch_play,
        )
        renderProgress()
    }

    private fun renderProgress() {
        val duration = playerState.durationMs
        if (duration <= 0) {
            progress.progress = 0
            return
        }
        val elapsedSinceUpdate = if (playerState.isPlaying) {
            (System.currentTimeMillis() - playerState.updatedAtMs).coerceAtLeast(0)
        } else {
            0
        }
        val position = (playerState.positionMs + elapsedSinceUpdate).coerceAtMost(duration)
        progress.progress = ((position * 1000) / duration).toInt()
    }

    private fun sendCommand(command: String) {
        connection.text = getString(R.string.watch_sending)
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                if (nodes.isEmpty()) {
                    connection.text = getString(R.string.watch_disconnected)
                    return@addOnSuccessListener
                }
                nodes.forEach { node ->
                    Wearable.getMessageClient(this)
                        .sendMessage(node.id, commandPath, command.toByteArray())
                        .addOnFailureListener {
                            connection.text = getString(R.string.watch_disconnected)
                        }
                }
            }
            .addOnFailureListener {
                connection.text = getString(R.string.watch_disconnected)
            }
    }

    private fun buildSurface(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            // Keep three 44dp touch targets inside compact 180/192dp watches.
            setPadding(dp(10), dp(14), dp(10), dp(14))
            setBackgroundColor(Color.rgb(18, 18, 18))
        }
        connection = TextView(this).apply {
            text = getString(R.string.watch_connecting)
            setTextColor(Color.rgb(218, 255, 72))
            textSize = 10f
            isAllCaps = true
            gravity = Gravity.CENTER
        }
        title = TextView(this).apply {
            text = "#zingChart"
            setTextColor(Color.rgb(255, 247, 240))
            textSize = 18f
            gravity = Gravity.CENTER
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(0, dp(8), 0, 0)
        }
        artist = TextView(this).apply {
            text = getString(R.string.watch_open_phone)
            setTextColor(Color.rgb(183, 179, 172))
            textSize = 12f
            gravity = Gravity.CENTER
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(0, dp(3), 0, 0)
        }
        progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 1000
            progressTintList = android.content.res.ColorStateList.valueOf(
                Color.rgb(255, 107, 94),
            )
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(
                Color.rgb(59, 58, 56),
            )
        }
        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        controls.addView(controlButton(R.drawable.ic_watch_previous, R.string.watch_previous) {
            sendCommand("previous")
        })
        playPause = controlButton(R.drawable.ic_watch_play, R.string.watch_play) {
            sendCommand("togglePlayPause")
        }
        controls.addView(playPause)
        controls.addView(controlButton(R.drawable.ic_watch_next, R.string.watch_next) {
            sendCommand("next")
        })
        root.addView(connection, rowParams())
        root.addView(title, rowParams())
        root.addView(artist, rowParams())
        root.addView(progress, rowParams().apply {
            topMargin = dp(12)
            height = dp(4)
        })
        root.addView(controls, rowParams().apply { topMargin = dp(12) })
        return root
    }

    private fun controlButton(icon: Int, label: Int, action: () -> Unit) =
        ImageButton(this).apply {
            setImageResource(icon)
            contentDescription = getString(label)
            setPadding(dp(10), dp(10), dp(10), dp(10))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(37, 36, 34))
            }
            setOnClickListener { action() }
            layoutParams = LinearLayout.LayoutParams(dp(44), dp(44)).apply {
                marginStart = dp(2)
                marginEnd = dp(2)
            }
        }

    private fun rowParams() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
    )

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val playerPath = "/zingchart/player"
        private const val commandPath = "/zingchart/command"
    }
}

private data class PlayerState(
    val title: String = "#zingChart",
    val artist: String = "",
    val isPlaying: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val updatedAtMs: Long = 0L,
)
