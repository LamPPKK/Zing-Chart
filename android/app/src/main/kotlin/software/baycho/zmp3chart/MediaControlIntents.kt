package software.baycho.zmp3chart

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import com.ryanheise.audioservice.MediaButtonReceiver

object MediaControlIntents {
    fun pendingIntent(context: Context, keyCode: Int, requestCode: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            requestCode,
            mediaButtonIntent(context, keyCode),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun send(context: Context, action: String) {
        val keyCode = when (action) {
            "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
            "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
            "togglePlayPause" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
            "stop" -> KeyEvent.KEYCODE_MEDIA_STOP
            else -> return
        }
        context.sendBroadcast(mediaButtonIntent(context, keyCode))
    }

    private fun mediaButtonIntent(context: Context, keyCode: Int) =
        Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(context, MediaButtonReceiver::class.java)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
}
