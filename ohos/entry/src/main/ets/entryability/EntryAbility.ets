
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import FileExportPlugin from '../plugins/FileExportPlugin';
import ReaderWakelockPlugin from '../plugins/ReaderWakelockPlugin';
import ReaderCutoutPlugin from '../plugins/ReaderCutoutPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    flutterEngine.getPlugins()?.add(new FileExportPlugin())
    flutterEngine.getPlugins()?.add(new ReaderWakelockPlugin())
    flutterEngine.getPlugins()?.add(new ReaderCutoutPlugin())
  }
}
