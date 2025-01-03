import 'package:zest/settings/settings_provider.dart';

Uri getAPIUrl(SettingsState settings, String path,
    {Map<String, dynamic>? queryParameters, withPostSlash = true}) {
  final midSlash = path.startsWith('/') ? '' : '/';
  final postSlash = path.endsWith('/') || !withPostSlash ? '' : '/';
  return Uri.parse('${settings.apiUrl}$midSlash$path$postSlash')
      .replace(queryParameters: queryParameters);
}
