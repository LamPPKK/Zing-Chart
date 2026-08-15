package software.baycho.zmp3chart

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class ZingChartWearListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != CompanionStateStore.commandPath) return
        MediaControlIntents.send(this, event.data.toString(Charsets.UTF_8))
    }
}
