import {
  FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler,
  MethodChannel, MethodResult, AbilityPluginBinding,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';

export default class FileExportPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private cacheDir: string | null = null;
  private saving: boolean = false;

  getUniqueClassName(): string { return 'ModuFileExportPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    // Match path_provider's application context, not the ability's module cache.
    this.cacheDir = binding.getApplicationContext().cacheDir;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'modu/file_export');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.context = null;
    this.cacheDir = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context;
  }

  onDetachedFromAbility(): void { this.context = null; }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'shareFile') {
      this.shareFile(call, result);
      return;
    }
    if (call.method !== 'saveFile') {
      result.notImplemented();
      return;
    }
    this.saveFile(call, result);
  }

  private async shareFile(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.saving || this.context === null || this.cacheDir === null) {
      result.error('unavailable', 'File sharing is busy or not in foreground', null);
      return;
    }
    this.saving = true;
    try {
      const args: Map<string, Object> = call.args;
      const sourcePath = args.get('sourcePath') as string;
      const fileName = args.get('fileName') as string;
      const prefix = this.cacheDir + '/modu-share-';
      const relative = sourcePath?.substring(prefix.length);
      if (!sourcePath || !fileName || !sourcePath.startsWith(prefix) ||
          /[/\\\x00]/.test(fileName) || fileName === '.' || fileName === '..' ||
          !relative || relative.split('/').length !== 2 ||
          relative.split('/')[0].length === 0 || relative.split('/')[0] === '..' ||
          relative.split('/')[1] !== fileName) {
        result.error('invalid_arguments', 'Invalid share snapshot', null);
        return;
      }
      const dot = fileName.lastIndexOf('.');
      const utd = dot >= 0
        ? uniformTypeDescriptor.getUniformDataTypeByFilenameExtension(fileName.substring(dot))
        : uniformTypeDescriptor.UniformDataType.FILE;
      const data = new systemShare.SharedData({
        utd: utd || uniformTypeDescriptor.UniformDataType.FILE,
        uri: fileUri.getUriFromPath(sourcePath),
        title: fileName,
      });
      const controller = new systemShare.ShareController(data);
      await controller.show(this.context, {});
      // Opening the sheet is not confirmation that a recipient received it.
      result.success(null);
    } catch (_) {
      result.error('share_failed', 'Could not open file sharing. Please retry.', null);
    } finally {
      this.saving = false;
    }
  }

  private async saveFile(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.saving || this.context === null || this.cacheDir === null) {
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
          !sourcePath.startsWith(this.cacheDir + '/modu-export-') ||
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
