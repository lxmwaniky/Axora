class AppConfig {
  /// Dev Shortcut: If true, scans a public device folder (e.g., Downloads)
  /// for the model file to bypass download wait times during judging.
  static const bool isHackathonSideloadEnabled = true;

  static const String hfModelRepo = "litert-community/gemma-4-E2B-it-litert-lm";
  static const String modelFilename = "gemma-4-E2B-it.litertlm";

  // Assistant Configuration
  static const String assistantName = "inkq Assistant";
  static const String defaultSystemInstruction =
      "You are inkq, an advanced on-device AI study assistant. "
      "You help students digest lecture recordings, notes, and textbook diagrams. "
      "Always respond in a helpful, structured, and educational tone. Keep it concise.";
}
