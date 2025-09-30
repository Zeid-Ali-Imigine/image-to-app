# Application Caméra avec Suppression de Fond BRIA RMBG-2.0

## Vue d'ensemble

Cette application Flutter complète intègre BRIA RMBG-2.0 pour supprimer automatiquement le fond des images capturées par l'appareil photo. L'application inclut un mode démo pour tester les fonctionnalités sans clé API.

## Configuration de l'API BRIA

### 1. Obtenir une clé API BRIA

1. Visitez [https://www.bria.ai/](https://www.bria.ai/)
2. Créez un compte gratuit
3. Accédez à votre dashboard
4. Générez une clé API

### 2. Configurer la clé API dans l'application

1. Ouvrez le fichier `lib/config/api_config.dart`
2. Remplacez `'VOTRE_CLE_API_BRIA'` par votre vraie clé API :

```dart
class ApiConfig {
  static const String briaApiKey = 'votre_vraie_cle_api_ici';
  // ... reste du code
}
```

### 3. Fonctionnalités Complètes

#### 📸 **Caméra Avancée**

- **Interface caméra professionnelle** avec contrôles complets
- **Contrôles de flash** (Off, Auto, On, Torch)
- **Contrôle d'exposition** avec indicateur visuel
- **Guide de cadrage** (rectangle/cercle) pour des prises optimales
- **Bouton de capture** grand et accessible
- **Prévisualisation en temps réel** des images capturées

#### 🎨 **Suppression de Fond BRIA RMBG-2.0**

- **Toggle de suppression de fond** : Activez/désactivez la suppression automatique
- **Mode démo intégré** : Testez sans clé API (simulation)
- **Traitement en arrière-plan** avec indicateurs visuels
- **Gestion d'erreurs robuste** avec fallback automatique

#### 🖼️ **Galerie Intelligente**

- **Images doubles** : Sauvegarde originale + sans fond
- **Indicateurs d'état** : En cours, terminé, erreur
- **Basculement facile** entre versions originale/traitée
- **Prévisualisation transparente** avec fond dégradé
- **Navigation fluide** entre écrans

#### 🎯 **Interface Utilisateur**

- **Design moderne** avec fond noir élégant
- **Indicateurs de statut** colorés et intuitifs
- **Messages d'information** contextuels
- **Bouton flottant** pour accéder à la galerie
- **Responsive design** adaptatif

### 4. Utilisation

#### 🚀 **Démarrage Rapide**

1. **Lancez l'application** : `flutter run`
2. **Mode démo** : Fonctionne immédiatement sans configuration
3. **Prenez des photos** avec le bouton de capture central
4. **Activez la suppression de fond** avec le toggle
5. **Consultez vos captures** via le bouton flottant bleu

#### 📱 **Interface Caméra**

- **Bouton de capture** : Cercle blanc au centre (grand et visible)
- **Contrôles flash** : 4 options en haut (Off, Auto, On, Torch)
- **Contrôle luminosité** : Bouton soleil à gauche
- **Prévisualisation** : Miniature à droite (dernière photo)
- **Guide de cadrage** : Rectangle vert pour cadrer vos sujets

#### 🎨 **Suppression de Fond**

- **Toggle "Suppression fond"** : Active/désactive le traitement
- **Mode démo** : Simulation sans clé API (copie l'image originale)
- **Mode production** : Traitement réel avec BRIA RMBG-2.0
- **Indicateurs visuels** : Statut du traitement en temps réel

### 5. Indicateurs Visuels

#### 🎨 **Couleurs et Statuts**

- 🟢 **Vert** : Suppression de fond active et API configurée
- 🔵 **Bleu** : Mode démo activé (fonctionne sans clé API)
- 🟠 **Orange** : Clé API non configurée
- 🔄 **Bleu rotatif** : Traitement en cours
- ✅ **Vert avec icône** : Image traitée avec succès
- ❌ **Rouge** : Erreur lors du traitement

#### 📱 **Interface Caméra**

- **Bouton capture** : Cercle blanc (80px) au centre
- **Flash actif** : Icônes ambre/orange
- **Guide de cadrage** : Rectangle vert (250px)
- **Contrôles** : Boutons blancs avec bordures

### 6. Dépannage

#### 🔧 **Problèmes Courants**

- **"Mode démo activé"** : Normal ! L'app fonctionne en simulation
- **"Clé API non configurée"** : Configurez votre clé API BRIA
- **Bouton capture invisible** : Vérifiez que l'appareil photo est initialisé
- **Erreur de traitement** : Vérifiez votre connexion internet et quota API
- **Images non traitées** : Les images originales sont toujours sauvegardées

#### 🚨 **Solutions**

- **Mode démo** : Parfait pour tester sans configuration
- **Configuration API** : Remplacez `VOTRE_CLE_API_BRIA` par votre vraie clé
- **Permissions caméra** : Autorisez l'accès à la caméra
- **Connexion** : Vérifiez votre connexion internet pour l'API

### 7. Structure Complète des Fichiers

```
lib/
├── config/
│   └── api_config.dart          # Configuration API BRIA + Mode démo
├── models/
│   └── processed_image.dart     # Modèle pour les images traitées
├── services/
│   └── background_removal_service.dart  # Service BRIA + Simulation
├── screens/
│   ├── camera_screen.dart       # Caméra complète + Contrôles
│   ├── captures_screen.dart     # Galerie intelligente
│   └── preview_screen.dart      # Prévisualisation transparente
├── main.dart                    # Point d'entrée de l'app
└── assets/
    ├── camera_aim.png          # Ressource graphique
    └── products.json           # Données produits

README_BRIA.md                  # Documentation complète
pubspec.yaml                    # Dépendances Flutter
```

#### 📁 **Fichiers Clés**

- **`camera_screen.dart`** : Interface caméra complète (1043 lignes)
- **`background_removal_service.dart`** : Service BRIA + mode démo
- **`api_config.dart`** : Configuration centralisée
- **`captures_screen.dart`** : Galerie avec indicateurs visuels

### 8. Commandes de Développement

#### 🚀 **Lancement**

```bash
# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run

# Lancer en mode debug
flutter run --debug

# Build pour production
flutter build apk
```

#### 🔧 **Maintenance**

```bash
# Nettoyer le cache
flutter clean

# Mettre à jour les dépendances
flutter pub upgrade

# Analyser le code
flutter analyze
```

## Support

Pour plus d'informations sur l'API BRIA, consultez [la documentation officielle](https://docs.bria.ai/).

---

**🎉 Application prête à l'emploi !** Fonctionne immédiatement en mode démo, configuration API optionnelle pour la production.
