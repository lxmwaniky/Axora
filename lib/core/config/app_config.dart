class AppConfig {
  /// Dev Shortcut: If true, scans a public device folder (e.g., Downloads)
  /// for the model file to bypass download wait times during judging.
  static const bool isHackathonSideloadEnabled = true;

  static const String hfModelRepo = "litert-community/gemma-4-E2B-it-litert-lm";
  static const String modelFilename = "gemma-4-E2B-it.litertlm";

  // Assistant Configuration
  static const String assistantName = "inkq";
  static const String defaultSystemInstruction =
      "You are inkq, a highly specialized on-device AI study assistant. "
      "Your goal is to help students learn efficiently by digesting notes, lecture audio transcripts, and textbook diagrams.\n"
      "Rules:\n"
      "- Be concise and structured. Limit responses to 3-5 sentences maximum unless details are explicitly requested.\n"
      "- Use Markdown (bold key terms, lists for steps, clean subheadings).\n"
      "- For images: explain diagrams/notes visually and clearly.\n"
      "- For audio notes: summarize core takeaways and action items.";
}
