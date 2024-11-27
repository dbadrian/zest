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
        name = 'zest.msix';
        break;
      }
    case 'linux':
      {
        name = 'zest.msix';
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
