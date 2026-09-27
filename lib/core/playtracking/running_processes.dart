import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Full paths (lower-case) of every executable currently running on this
/// PC. Uses the Win32 API directly instead of PowerShell so polling it every
/// minute is cheap and never flashes a console window. Empty elsewhere.
Set<String> runningExecutablePaths() {
  if (!Platform.isWindows) return {};
  return using((arena) {
    const maxProcesses = 4096;
    const maxPathChars = 1024;
    final pids = arena<Uint32>(maxProcesses);
    final bytesReturned = arena<Uint32>();
    if (!EnumProcesses(
      pids,
      maxProcesses * sizeOf<Uint32>(),
      bytesReturned,
    ).value) {
      return <String>{};
    }

    final count = bytesReturned.value ~/ sizeOf<Uint32>();
    final buffer = arena<Uint16>(maxPathChars).cast<Utf16>();
    final length = arena<Uint32>();
    final paths = <String>{};
    for (var i = 0; i < count; i++) {
      final pid = pids[i];
      if (pid == 0) continue;
      // Processes of other users or protected ones simply fail to open.
      final handle = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION,
        false,
        pid,
      ).value;
      if (!handle.isValid) continue;
      length.value = maxPathChars;
      if (QueryFullProcessImageName(
        handle,
        PROCESS_NAME_WIN32,
        PWSTR(buffer),
        length,
      ).value) {
        paths.add(buffer.toDartString(length: length.value).toLowerCase());
      }
      handle.close();
    }
    return paths;
  });
}
