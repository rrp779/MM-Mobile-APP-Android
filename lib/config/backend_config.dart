class BackendConfig {
  static const String baseUrl = String.fromEnvironment(
    "BACKEND_BASE_URL",
    defaultValue: "https://mm-backend-production-f67e.up.railway.app/api",
  );
} 
