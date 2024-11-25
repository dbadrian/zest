// ignore_for_file: constant_identifier_names
const AVAILABLE_LANGUAGES = {
  "en": "English",
  "de": "German",
  "it": "Italian",
  "fr": "French",
  "cz": "Czech"
};

const DEFAULT_LANGUAGE = "de";

/// Networking

/// Used in checks, whether use will be authenticated long enough for safe
/// execution
const SAFE_AUTH_DURATION = Duration(days: 1);

/// UI related
const MAX_TAG_LENGTH = 25;

const MAX_HISTORY_STEPS = 1000;

/// Used in search results
const int INGREDIENT_SEARCH_PAGE_SIZE = 5;
const int RECIPE_SEARCH_DEFAULT_PAGE_SIZE = 50;

const String RECIPE_DRAFT_DB_KEY = "recipedrafts";
