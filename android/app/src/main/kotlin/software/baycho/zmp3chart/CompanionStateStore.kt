package software.baycho.zmp3chart

import android.content.Context
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

data class CompanionState(
    val songId: String,
    val title: String,
    val artist: String,
    val artworkUrl: String,
    val status: String,
    val isPlaying: Boolean,
    val positionMs: Long,
    val durationMs: Long,
    val canGoPrevious: Boolean,
    val canGoNext: Boolean,
    val updatedAtMs: Long,
)

object CompanionStateStore {
    private const val preferencesName = "zingchart_companion"
    const val dataPath = "/zingchart/player"
    const val commandPath = "/zingchart/command"

    fun save(context: Context, values: Map<*, *>) {
        val state = CompanionState(
            songId = values["songId"] as? String ?: "",
            title = values["title"] as? String ?: "#zingChart",
            artist = values["artist"] as? String ?: "Chưa chọn bài hát",
            artworkUrl = values["artworkUrl"] as? String ?: "",
            status = values["status"] as? String ?: "idle",
            isPlaying = values["isPlaying"] as? Boolean ?: false,
            positionMs = (values["positionMs"] as? Number)?.toLong() ?: 0L,
            durationMs = (values["durationMs"] as? Number)?.toLong() ?: 0L,
            canGoPrevious = values["canGoPrevious"] as? Boolean ?: false,
            canGoNext = values["canGoNext"] as? Boolean ?: false,
            updatedAtMs = (values["updatedAtMs"] as? Number)?.toLong() ?: 0L,
        )
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putString("songId", state.songId)
            .putString("title", state.title)
            .putString("artist", state.artist)
            .putString("artworkUrl", state.artworkUrl)
            .putString("status", state.status)
            .putBoolean("isPlaying", state.isPlaying)
            .putLong("positionMs", state.positionMs)
            .putLong("durationMs", state.durationMs)
            .putBoolean("canGoPrevious", state.canGoPrevious)
            .putBoolean("canGoNext", state.canGoNext)
            .putLong("updatedAtMs", state.updatedAtMs)
            .apply()
        ZingChartWidgetProvider.updateAll(context)
        publishToWearOs(context, state)
    }

    fun load(context: Context): CompanionState {
        val values = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        return CompanionState(
            songId = values.getString("songId", "") ?: "",
            title = values.getString("title", "#zingChart") ?: "#zingChart",
            artist = values.getString("artist", context.getString(R.string.widget_no_song))
                ?: context.getString(R.string.widget_no_song),
            artworkUrl = values.getString("artworkUrl", "") ?: "",
            status = values.getString("status", "idle") ?: "idle",
            isPlaying = values.getBoolean("isPlaying", false),
            positionMs = values.getLong("positionMs", 0L),
            durationMs = values.getLong("durationMs", 0L),
            canGoPrevious = values.getBoolean("canGoPrevious", false),
            canGoNext = values.getBoolean("canGoNext", false),
            updatedAtMs = values.getLong("updatedAtMs", 0L),
        )
    }

    private fun publishToWearOs(context: Context, state: CompanionState) {
        try {
            val request = PutDataMapRequest.create(dataPath).apply {
                dataMap.putInt("schemaVersion", 1)
                dataMap.putString("songId", state.songId)
                dataMap.putString("title", state.title)
                dataMap.putString("artist", state.artist)
                dataMap.putString("status", state.status)
                dataMap.putBoolean("isPlaying", state.isPlaying)
                dataMap.putLong("positionMs", state.positionMs)
                dataMap.putLong("durationMs", state.durationMs)
                dataMap.putBoolean("canGoPrevious", state.canGoPrevious)
                dataMap.putBoolean("canGoNext", state.canGoNext)
                dataMap.putLong("updatedAtMs", state.updatedAtMs)
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(request)
        } catch (_: Throwable) {
            // Google Play services is optional: Fire OS widgets keep working.
        }
    }
}
