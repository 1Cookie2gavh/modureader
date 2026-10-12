import {
  FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler,
  MethodChannel, MethodResult, AbilityPluginBinding,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';

export default class FileExportPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private saving: boolean = false;

  getUniqueClassName(): string { return 'ModuFileExportPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'modu/file_export');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.context = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context;
  }

  onDetachedFromAbility(): void { this.context = null; }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'saveFile') {
      result.notImplemented();
      return;
    }
    this.saveFile(call, result);
  }

  private async saveFile(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.saving || this.context === null) {
      result.error('unavailable', 'File export is busy or not in foreground', null);
      return;
    }
    this.saving = true;
    try {
      const args: Map<string, Object> = call.args;
      const sourcePath = args.get('sourcePath') as string;
      const fileName = args.get('fileName') as string;
      if (!sourcePath || !fileName || /[/\\\x00]/.test(fileName) ||
          fileName === '.' || fileName === '..' ||
          !sourcePath.startsWith(this.context.cacheDir + '/modu-export-') ||
          sourcePath.includes('/../')) {
        result.error('invalid_arguments', 'Invalid export snapshot', null);
        return;
      }
      // The pinned file_picker adapter ignores bytes and mishandles cancellation.
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const uris = await new picker.DocumentViewPicker(this.context).save(options);
      if (uris.length === 0) {
        result.success(null);
        return;
      }
      const source = await fs.open(sourcePath, fs.OpenMode.READ_ONLY);
      try {
        const destination = await fs.open(uris[0], fs.OpenMode.READ_WRITE);
        try {
          await fs.copyFile(source.fd, destination.fd);
        } finally {
          await fs.close(destination);
        }
      } finally {
        await fs.close(source);
      }
      result.success(uris[0]);
    } catch (_) {
      // Never expose private paths or log contents in platform error messages.
      result.error('export_failed', 'Could not save the file. Please retry.', null);
    } finally {
      this.saving = false;
    }
  }
}
