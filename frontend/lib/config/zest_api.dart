// ignore_for_file: constant_identifier_names

import 'package:zest/utils/utils.dart';

// TODO: Set to empty string for (v.1.0.0) release
const String DEFAULT_API_URL = 'https://dbadrian.com/api/v1';

///
const API_RECIPE_SEARCH_FIELDS = {
  // ui-key: Pair("django_key", on_by_default)
  "Title": Pair("title", true),
  "Subtitle": Pair("subtitle", false),
  // "Owner Comment": Pair("owner_comment", false),
  // "Source Name": Pair("source_name", false),
  // "Source URL": Pair("source_url", false)
};
