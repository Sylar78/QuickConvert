# QuickConvert 🚀

> **"Convertis tes fichiers instantanément depuis ton smartphone."**

Application mobile Flutter pour la conversion rapide de fichiers entre PDF, JPG, PNG et DOC.

---

## 📱 Fonctionnalités MVP

| Conversion | Statut |
|---|---|
| PDF → JPG | ✅ Local + Cloud |
| JPG → PDF | ✅ Local + Cloud |
| PNG → JPG / JPG → PNG | ✅ Local |
| DOC/DOCX → PDF | ✅ Cloud (LibreOffice) |
| Partage rapide | ✅ (WhatsApp, Mail, AirDrop, Drive) |
| Historique | ✅ Local (Hive) |
| Publicités AdMob | ✅ Banner + Interstitiel |
| Premium (4,99€/mois) | ✅ In-App Purchase |

---

## 🗂️ Structure du projet

```
app/
├── lib/
│   ├── core/           # Thème, couleurs, constantes
│   ├── models/         # Modèles de données (Hive, JSON)
│   ├── providers/      # State management (Provider)
│   ├── services/       # Conversion, Supabase, AdMob, Share, Historique
│   ├── screens/        # Écrans (Home, Conversion, History, Premium, Auth, Settings)
│   ├── widgets/        # Composants réutilisables
│   ├── router/         # Navigation
│   ├── app.dart        # Root widget
│   └── main.dart       # Point d'entrée
├── android/            # Config Android (permissions, AdMob, Kotlin)
├── ios/                # Config iOS (Info.plist, permissions)
├── supabase/           # Schema SQL (profiles, logs, storage, RLS)
├── backend/            # API Node.js + Docker (conversion cloud)
│   ├── api/
│   │   └── src/
│   │       ├── index.js      # Express routes
│   │       ├── converters.js # Logique de conversion
│   │       └── logger.js
│   └── docker-compose.yml
└── pubspec.yaml
```

---

## 🚀 Installation

### Prérequis
- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.3.0
- Android Studio / Xcode
- Compte [Supabase](https://supabase.com)
- Compte [Google AdMob](https://admob.google.com)

### 1. Cloner & installer

```bash
cd app
flutter pub get
```

### 2. Configurer Supabase

1. Crée un projet sur [supabase.com](https://supabase.com)
2. Exécute `supabase/schema.sql` dans le SQL Editor
3. Copie ton URL et ta clé anonyme dans `lib/core/constants.dart` :

```dart
static const String supabaseUrl = 'https://TON_PROJET.supabase.co';
static const String supabaseAnonKey = 'ta_cle_anon';
```

### 3. Configurer AdMob

Remplace les IDs test dans `lib/core/constants.dart` par tes vrais IDs AdMob :

```dart
static const String admobBannerIdAndroid = 'ca-app-pub-XXXXXXXX/XXXXXXXX';
static const String admobInterstitialIdAndroid = 'ca-app-pub-XXXXXXXX/XXXXXXXX';
```

Et dans les manifestes natifs :
- **Android** : `android/app/src/main/AndroidManifest.xml` → `GAD_APPLICATION_ID`
- **iOS** : `ios/Runner/Info.plist` → `GADApplicationIdentifier`

### 4. Lancer l'app

```bash
flutter run
```

---

## 🖥️ Backend Cloud (optionnel — DOC→PDF, OCR)

```bash
cd backend
cp .env.example .env  # Remplir les variables
docker-compose up -d
```

L'API sera disponible sur `http://localhost:3000`.

Variables d'environnement requises :
```env
SUPABASE_URL=https://TON_PROJET.supabase.co
SUPABASE_SERVICE_KEY=ta_cle_service
LIBREOFFICE_PASSWORD=ton_mot_de_passe
```

---

## 💰 Monétisation

| Plan | Prix | Limite |
|---|---|---|
| Gratuit | 0€ | 5 conversions/jour + pubs |
| Premium Mensuel | 4,99€/mois | Illimité, sans pub, OCR |
| Premium Annuel | 35,88€/an (2,99€/mois) | Idem + -40% |

---

## 📊 KPIs cibles

- **J+90** : 10k–50k téléchargements
- **M+6** : 500–1500€/mois récurrents
- **Taux conversion Premium** : > 2%
- **Premier fichier converti** : > 70% des utilisateurs

---

## 🛠️ Stack technique

| Composant | Technologie |
|---|---|
| Frontend | Flutter (iOS + Android) |
| State | Provider + ChangeNotifier |
| Backend auth/DB | Supabase |
| Stockage local | Hive |
| Conversion locale | pdf, pdfx, image, flutter_image_compress |
| Conversion cloud | Node.js + LibreOffice + sharp |
| Pub | Google AdMob |
| Achat | In-App Purchase |
| Partage | share_plus |

---

## 🗺️ Roadmap

### Semaine 1 ✅
- [x] UI & navigation
- [x] Architecture providers/services
- [x] Conversions locales (PDF↔JPG, PNG↔JPG)

### Semaine 2
- [x] Partage rapide
- [x] Historique
- [x] Publicités AdMob

### Semaine 3
- [x] Paiements Premium
- [ ] Analytics Supabase
- [ ] Backend cloud (DOC→PDF)

### Semaine 4
- [ ] Publication App Store + Play Store
- [ ] Marketing TikTok
- [ ] ASO (mots-clés: PDF converter, JPG to PDF...)

### V2
- [ ] OCR (photo → texte)
- [ ] Compression PDF
- [ ] Fusion PDF
- [ ] Scanner document IA

---

## 📄 Licence

MIT — © 2026 QuickConvert
