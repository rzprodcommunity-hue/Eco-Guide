/// Supabase project used by Eco-Guide. The anon key is a public client key
/// (the same one shipped with the main Eco-Guide app) and only grants the
/// read access allowed by the database's row-level security policies.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://swpyvimuaufphsbkstcd.supabase.co';

  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN3cHl2aW11YXVmcGhzYmtzdGNkIiwicm9sZSI6'
      'ImFub24iLCJpYXQiOjE3ODE1MTYwNDcsImV4cCI6MjA5NzA5MjA0N30.'
      'Bs4QOMC1cE8XvxvfvIEdcW0oNjszPmgUTuHo3I1ytz4';

  /// PostgREST base for table queries.
  static String get restUrl => '$url/rest/v1';
}

