import {
  FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler, MethodChannel, MethodResult,
} from '@ohos/flutter_ohos';
import { Want } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

// The share_handler dependency has no OHOS implementation. Resolve granted
// Want URIs natively rather than passing provider URIs to Dart File().
export default class ExternalBookFilesPlugin implements FlutterPlugin, MethodCallHandler {
  static readonly shared: ExternalBookFilesPlugin = new ExternalBookFilesPlugin();
  private channel: MethodChannel | null = null;
  private ready: boolean = false;
  private pending: string[] = [];
  private failed: boolean = false;
  private active: Set<string> = new Set<string>();

  getUniqueClassName(): string { return 'ModuExternalBookFilesPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.modu.reader/external_files');
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.ready = false;
  }
  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'ready') { result.notImplemented(); return; }
    this.ready = true;
    result.success(this.pending);
    this.pending = [];
    if (this.failed) { this.failed = false; this.reportError(); }
  }
  receive(want: Want, cacheDir: string): void {
    if (!['ohos.want.action.viewData', 'ohos.want.action.sendData',
      'ohos.want.action.sendMultipleData'].includes(want.action ?? '')) return;
    const uris: Set<string> = new Set<string>();
    if (want.uri) uris.add(want.uri);
    const streams = want.parameters?.['ability.params.stream'];
    if (typeof streams === 'string') uris.add(streams);
    else if (Array.isArray(streams)) {
      for (const uri of streams as string[]) { if (typeof uri === 'string') uris.add(uri); }
    }
    for (const uri of uris) {
      if (!uri.startsWith('file://') || this.active.has(uri)) continue;
      this.active.add(uri);
      this.stage(uri, cacheDir);
    }
  }
  private reportError(): void {
    if (this.ready) this.channel?.invokeMethod('error', 'Unable to read the shared book. Check file access and retry.');
    else this.failed = true;
  }
  private async stage(uri: string, cacheDir: string): Promise<void> {
    const folder = cacheDir + '/modu-open-' + util.generateRandomUUID();
    let source: fs.File | null = null;
    try {
      const name = new fileUri.FileUri(uri).name;
      if (!name || /[/\\\x00]/.test(name) ||
        !/\.(epub|mobi|azw3|fb2|txt|pdf|md|markdown|umd)$/i.test(name)) return;
      source = await fs.open(uri, fs.OpenMode.READ_ONLY);
      if (!(await fs.stat(source.fd)).isFile()) throw new Error('Not a regular file');
      await fs.mkdir(folder);
      const target = folder + '/' + name;
      await fs.copyFile(source.fd, target);
      if (this.ready) this.channel?.invokeMethod('files', [target]);
      else this.pending.push(target);
    } catch (_) {
      try { await fs.rmdir(folder); } catch (_) { }
      this.reportError();
    } finally {
      if (source !== null) { try { await fs.close(source); } catch (_) { } }
      this.active.delete(uri);
    }
  }
}
