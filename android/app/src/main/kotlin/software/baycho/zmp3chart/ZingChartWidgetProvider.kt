package software.baycho.zmp3chart

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.widget.RemoteViews

class ZingChartWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, views(context)) }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, ZingChartWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach {
                manager.updateAppWidget(it, views(context))
            }
        }

        private fun views(context: Context): RemoteViews {
            val state = CompanionStateStore.load(context)
            val progress = if (state.durationMs > 0) {
                ((state.positionMs.coerceAtMost(state.durationMs) * 1000) / state.durationMs).toInt()
            } else {
                0
            }
            return RemoteViews(context.packageName, R.layout.zingchart_widget).apply {
                setTextViewText(R.id.widget_title, state.title)
                setTextViewText(R.id.widget_artist, state.artist)
                setProgressBar(R.id.widget_progress, 1000, progress, state.durationMs <= 0)
                setImageViewResource(
                    R.id.widget_play_pause,
                    if (state.isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
                )
                setContentDescription(
                    R.id.widget_play_pause,
                    context.getString(
                        if (state.isPlaying) R.string.widget_pause else R.string.widget_play,
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_previous,
                    MediaControlIntents.pendingIntent(
                        context,
                        KeyEvent.KEYCODE_MEDIA_PREVIOUS,
                        2101,
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_play_pause,
                    MediaControlIntents.pendingIntent(
                        context,
                        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                        2102,
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_next,
                    MediaControlIntents.pendingIntent(
                        context,
                        KeyEvent.KEYCODE_MEDIA_NEXT,
                        2103,
                    ),
                )
                setOnClickPendingIntent(R.id.widget_surface, openApp(context))
            }
        }

        private fun openApp(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                2100,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
