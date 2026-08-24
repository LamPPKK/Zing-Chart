import { AbilityConstant, Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, formProvider } from '@kit.FormKit';
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

const CHANNEL = 'software.baycho.zmp3chart/companion';
const DEEP_LINK_CHANNEL = 'software.baycho.zmp3chart/deep_link';
const STORE = 'zingchart_companion';

export default class EntryAbility extends FlutterAbility {
  private companionChannel?: MethodChannel;
  private deepLinkChannel?: MethodChannel;
  private pendingCompanionAction?: string;
  private pendingOfficialRoute?: string;
  private dartDeepLinkReady: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.pendingCompanionAction = want.parameters?.companionAction as string | undefined;
    this.pendingOfficialRoute = want.uri;
    super.onCreate(want, launchParam);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    this.companionChannel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      CHANNEL
    );
    const ability = this;
    this.companionChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        if (call.method !== 'publishSnapshot') {
          result.notImplemented();
          return;
        }
        ability.publishSnapshot(call.arguments as Record<string, Object>)
          .then(() => {
            result.success(null);
            ability.flushPendingCompanionAction();
          })
          .catch((error: Error) => result.error('snapshot_write_failed', error.message, null));
      }
    } as MethodCallHandler);
    this.deepLinkChannel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      DEEP_LINK_CHANNEL
    );
    this.deepLinkChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        if (call.method === 'getInitialRoute') {
          const route = ability.pendingOfficialRoute;
          ability.pendingOfficialRoute = undefined;
          result.success(route ?? null);
          return;
        }
        if (call.method === 'ready') {
          ability.dartDeepLinkReady = true;
          result.success(null);
          ability.flushPendingOfficialRoute();
          return;
        }
        result.notImplemented();
      }
    } as MethodCallHandler);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParam);
    const action = want.parameters?.companionAction as string | undefined;
    if (action) {
      this.pendingCompanionAction = action;
      this.flushPendingCompanionAction();
    }
    const route = want.uri;
    if (route) {
      this.pendingOfficialRoute = route;
      this.flushPendingOfficialRoute();
    }
  }

  private flushPendingOfficialRoute(): void {
    const route = this.pendingOfficialRoute;
    if (!route || !this.deepLinkChannel || !this.dartDeepLinkReady) return;
    this.pendingOfficialRoute = undefined;
    this.deepLinkChannel.invokeMethod('open', { route: route });
  }

  private flushPendingCompanionAction(): void {
    const action = this.pendingCompanionAction;
    if (!action || !this.companionChannel) return;
    this.pendingCompanionAction = undefined;
    this.companionChannel.invokeMethod('command', { action: action });
  }

  private async publishSnapshot(snapshot: Record<string, Object>): Promise<void> {
    const store = await preferences.getPreferences(this.context, { name: STORE });
    await store.put('playerSnapshot', JSON.stringify(snapshot));
    await store.flush();
    const formIds = JSON.parse(
      await store.get('formIds', '[]') as string
    ) as string[];
    const binding = formBindingData.createFormBindingData(snapshot);
    await Promise.all(formIds.map((formId: string) => formProvider.updateForm(formId, binding)));
  }
}
