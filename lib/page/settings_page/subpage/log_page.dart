import 'package:anx_reader/utils/app_motion.dart';
import 'dart:io';

import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/utils/save_file_to_download.dart';
import 'package:anx_reader/utils/get_path/log_file.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _LogAction { export, clear }

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<String> logs = [];
  bool _exporting = false;

  @override
  void initState() {
    initData();
    super.initState();
  }

  Future<void> initData() async {
    File logFile = await getLogFile();
    if (!mounted) return;
    setState(() {
      logs = logFile.readAsLinesSync().reversed.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).settingsAdvancedLog),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              initData();
            },
          ),
          PopupMenuButton<_LogAction>(
            popUpAnimationStyle: AppMotion.style,
            onSelected: (action) {
              switch (action) {
                case _LogAction.export:
                  exportLog();
                case _LogAction.clear:
                  clearLog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _LogAction.export,
                enabled: !_exporting,
                child: Row(children: [
                  const Icon(Icons.file_upload_outlined),
                  const SizedBox(width: 12),
                  Text(L10n.of(context).settingsAdvancedLogExportLog),
                ]),
              ),
              PopupMenuItem(
                value: _LogAction.clear,
                enabled: !_exporting,
                child: Row(children: [
                  const Icon(Icons.delete),
                  const SizedBox(width: 12),
                  Text(L10n.of(context).settingsAdvancedLogClearLog),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [for (final log in logs) logItem(log, context)],
      ),
    );
  }

  Future<void> clearLog() async {
    AnxLog.clear();
    await initData();
  }

  Future<void> exportLog() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final logFile = await getLogFile();
      final date = DateTime.now();
      final fileName = 'Modu-Log-${date.year}-${date.month}-${date.day}.txt';
      final filePath = await saveFileToDownload(
          sourceFilePath: logFile.path,
          fileName: fileName,
          mimeType: 'text/plain');
      if (mounted && filePath != null && filePath.isNotEmpty) {
        AnxToast.show('${L10n.of(context).commonSaveSuccess}: $fileName',
            context: context);
      }
    } catch (error) {
      AnxLog.warning('Log export failed: ${error.runtimeType}');
      if (mounted) {
        AnxToast.show(
            ModuStrings.text(context, '日志导出失败，请重试。原日志已保留。',
                'Could not export logs. Please retry; the original log is unchanged.'),
            context: context);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

Widget logItem(String logStr, BuildContext context) {
  final log = AnxLog.parse(logStr);
  return SelectionArea(
      child: Container(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 1, 8, 1),
          decoration: BoxDecoration(
            color: log.color,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(log.level.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
        Text(log.time.toString()),
        const SizedBox(height: 5),
        Text(log.message),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: logStr));
              },
              child: Text(L10n.of(context).commonCopy),
            ),
          ],
        ),
        const Divider(),
      ],
    ),
  ));
}
