class ApiConfig {
  // Configuration BRIA
  static const String briaApiKey = 'VOTRE_CLE_API_BRIA';
  static const String briaBaseUrl = 'https://engine.prod.bria-api.com/v1';
  static const String backgroundRemovalEndpoint = '/background/remove';
  static String get backgroundRemovalUrl =>
      '$briaBaseUrl$backgroundRemovalEndpoint';
  static bool get isApiKeyConfigured => briaApiKey != 'VOTRE_CLE_API_BRIA';

  // Mode démo (aucun appel réseau)
  static const bool demoMode = false;

  // Configuration Hugging Face (RMBG-2.0)
  // Renseignez ici votre token Hugging Face (format: hf_XXXX...)
  static const String huggingFaceToken = '';
  // Endpoint du modèle BRIA RMBG-2.0 sur Hugging Face Inference API
  static const String huggingFaceModelEndpoint =
      'https://api-inference.huggingface.co/models/briaai/RMBG-2.0';
  // Choisir le fournisseur: true -> Hugging Face, false -> BRIA direct
  static const bool useHuggingFace = true;

  static bool get isHuggingFaceConfigured =>
      huggingFaceToken != '' && huggingFaceToken.isNotEmpty;
}
