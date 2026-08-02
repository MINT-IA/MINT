import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'mint_next_localizations_de.dart';
import 'mint_next_localizations_en.dart';
import 'mint_next_localizations_es.dart';
import 'mint_next_localizations_fr.dart';
import 'mint_next_localizations_it.dart';
import 'mint_next_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of MintNextLocalizations
/// returned by `MintNextLocalizations.of(context)`.
///
/// Applications need to include `MintNextLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/mint_next_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: MintNextLocalizations.localizationsDelegates,
///   supportedLocales: MintNextLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the MintNextLocalizations.supportedLocales
/// property.
abstract class MintNextLocalizations {
  MintNextLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static MintNextLocalizations of(BuildContext context) {
    return Localizations.of<MintNextLocalizations>(
      context,
      MintNextLocalizations,
    )!;
  }

  static const LocalizationsDelegate<MintNextLocalizations> delegate =
      _MintNextLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt'),
  ];

  /// No description provided for @brand.
  ///
  /// In fr, this message translates to:
  /// **'MINT'**
  String get brand;

  /// No description provided for @quit.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get quit;

  /// No description provided for @todayEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'AUJOURD’HUI · 3A'**
  String get todayEyebrow;

  /// No description provided for @todayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Que change un versement 3a cette année ?'**
  String get todayTitle;

  /// No description provided for @todayBody.
  ///
  /// In fr, this message translates to:
  /// **'On va comprendre ses effets, une étape à la fois. MINT t’informe, mais ne décide pas à ta place.'**
  String get todayBody;

  /// No description provided for @start.
  ///
  /// In fr, this message translates to:
  /// **'Comprendre'**
  String get start;

  /// No description provided for @orientationEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'AVANT LES CHIFFRES'**
  String get orientationEyebrow;

  /// No description provided for @orientationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Épargner pour ta retraite peut aussi réduire tes impôts.'**
  String get orientationTitle;

  /// No description provided for @orientationBody.
  ///
  /// In fr, this message translates to:
  /// **'Un versement 3a peut diminuer ton revenu imposable — le montant sur lequel tes impôts sont calculés. Ton argent disponible baisse maintenant et le capital 3a reste lié jusqu’à la retraite, sauf dans les cas prévus par la loi.'**
  String get orientationBody;

  /// No description provided for @orientationNote.
  ///
  /// In fr, this message translates to:
  /// **'On vérifiera d’abord l’année et ta situation. Aucun montant ne sera recommandé.'**
  String get orientationNote;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @backLabel.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get backLabel;

  /// No description provided for @taxYearEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'ÉTAPE 1 · ANNÉE FISCALE'**
  String get taxYearEyebrow;

  /// No description provided for @taxYearTitle.
  ///
  /// In fr, this message translates to:
  /// **'De quelle année parle-t-on ?'**
  String get taxYearTitle;

  /// No description provided for @taxYearBody.
  ///
  /// In fr, this message translates to:
  /// **'Le plafond dépend de l’année et de ta situation, notamment de ton revenu professionnel et de ton affiliation à une caisse de pension. L’année en cours est proposée, jamais choisie à ta place.'**
  String get taxYearBody;

  /// No description provided for @currentYearLabel.
  ///
  /// In fr, this message translates to:
  /// **'Année en cours : {year}'**
  String currentYearLabel(int year);

  /// No description provided for @confirmYear.
  ///
  /// In fr, this message translates to:
  /// **'Choisir {year}'**
  String confirmYear(int year);

  /// No description provided for @yearChosen.
  ///
  /// In fr, this message translates to:
  /// **'Année {year} sélectionnée'**
  String yearChosen(int year);

  /// No description provided for @partialBoundary.
  ///
  /// In fr, this message translates to:
  /// **'Le prochain écran sera ajouté dans le lot suivant. Rien n’est enregistré.'**
  String get partialBoundary;

  /// No description provided for @safeExitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu veux t’arrêter ici ?'**
  String get safeExitTitle;

  /// No description provided for @safeExitBody.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée financière personnelle n’est enregistrée dans ce Design Lab.'**
  String get safeExitBody;

  /// No description provided for @resume.
  ///
  /// In fr, this message translates to:
  /// **'Continuer ici'**
  String get resume;

  /// No description provided for @leave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter sans enregistrer'**
  String get leave;

  /// No description provided for @dismissedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parcours fermé'**
  String get dismissedTitle;

  /// No description provided for @startShort.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get startShort;

  /// No description provided for @keepReferenceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Repère local — bientôt disponible'**
  String get keepReferenceUnavailable;
}

class _MintNextLocalizationsDelegate
    extends LocalizationsDelegate<MintNextLocalizations> {
  const _MintNextLocalizationsDelegate();

  @override
  Future<MintNextLocalizations> load(Locale locale) {
    return SynchronousFuture<MintNextLocalizations>(
      lookupMintNextLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_MintNextLocalizationsDelegate old) => false;
}

MintNextLocalizations lookupMintNextLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return MintNextLocalizationsDe();
    case 'en':
      return MintNextLocalizationsEn();
    case 'es':
      return MintNextLocalizationsEs();
    case 'fr':
      return MintNextLocalizationsFr();
    case 'it':
      return MintNextLocalizationsIt();
    case 'pt':
      return MintNextLocalizationsPt();
  }

  throw FlutterError(
    'MintNextLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
