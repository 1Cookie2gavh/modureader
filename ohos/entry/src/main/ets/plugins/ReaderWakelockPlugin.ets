import {
  FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler,
  MethodChannel, MethodResult, AbilityPluginBinding,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';

export default class ReaderWakelockPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private activeWindow: window.Window | null = null;

  getUniqueClassName(): string { return 'ModuReaderWakelockPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'modu/reader_wakelock');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.onDetachedFromAbility();
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context;
  }

  onDetachedFromAbility(): void {
    this.context = null;
    this.activeWindow?.setWindowKeepScreenOn(false).catch(() => {});
    this.activeWindow = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'toggle') {
      result.notImplemented();
      return;
    }
    this.toggle(call, result);
  }

  private async toggle(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const args: Map<string, Object> = call.args;
      const enabled = args.get('enabled');
      if (typeof enabled !== 'boolean') {
        result.error('invalid_arguments', 'Expected enabled boolean', null);
        return;
      }
      const context = this.context;
      if (context === null) {
        result.error('unavailable', 'Reader window is not attached', null);
        return;
      }
      const target = await window.getLastWindow(context);
      if (this.context !== context) {
        result.error('unavailable', 'Reader window was detached', null);
        return;
      }
      this.activeWindow = target;
      await target.setWindowKeepScreenOn(enabled);
      if (this.context !== context) {
        // Detachment can race completion of the native enable operation.
        await target.setWindowKeepScreenOn(false);
        result.error('unavailable', 'Reader window was detached', null);
        return;
      }
      result.success(null);
    } catch (_) {
      result.error('wakelock_failed', 'Could not change reader keep-screen-on state', null);
    }
  }
}
