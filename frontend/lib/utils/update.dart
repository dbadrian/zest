import 'dart:io';

String get platformUpdateExt {
  switch (Platform.operatingSystem) {
    case 'windows':
      {
        return 'msix';
      }
    case 'linux':
      {
        return 'AppImage';
      }
    case 'android':
      {
        return "aab";
      }
    default:
      {
        return 'zip';
      }
  }
}

String platformUpdateName(String? latestVersion) {
  var name = "";
  switch (Platform.operatingSystem) {
    case 'windows':
      {
        name = 'zest-v$latestVersion.msix';
        break;
      }
    case 'linux':
      {
        // Just for development debugging purposes
        name = 'zest-v$latestVersion.msix';
        break;
      }
    case 'android':
      {
        name = 'app-release-signed.aab';
        break;
      }
    default:
      {
        name = 'zip';
        return "INVALID";
      }
  }
  return name;
}
