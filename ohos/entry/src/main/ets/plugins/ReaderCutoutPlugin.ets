import {
  FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler,
  MethodChannel, MethodResult, AbilityPluginBinding,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';

export default class ReaderCutoutPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;

  getUniqueClassName(): string { return 'ModuReaderCutoutPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'modu/reader_cutout');
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

  onDetachedFromAbility(): void { this.context = null; }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'getInsets') {
      result.notImplemented();
      return;
    }
    this.getInsets(result);
  }

  private async getInsets(result: MethodResult): Promise<void> {
    try {
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
      // TYPE_SYSTEM can become empty in immersive mode. Hardware cutouts remain.
      const area = target.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const bounds = target.getWindowProperties().windowRect;
      const insets: number[] = [
        area.leftRect.width > 0 ? area.leftRect.left + area.leftRect.width : 0,
        area.topRect.height > 0 ? area.topRect.top + area.topRect.height : 0,
        area.rightRect.width > 0 ? bounds.width - area.rightRect.left : 0,
        area.bottomRect.height > 0 ? bounds.height - area.bottomRect.top : 0,
      ];
      // Return physical pixels; Flutter applies the current view's pixel ratio.
      result.success(insets);
    } catch (_) {
      result.error('cutout_unavailable', 'Could not read reader cutout area', null);
    }
  }
}
