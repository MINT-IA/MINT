import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/services/open_banking_service.dart';

/// Unit tests for OpenBankingService
///
/// Tests the Open Banking (bLink/SFTI) service including:
///   - FINMA gate configuration & constants
///   - BankingConsent model: active/expired/revoked states, expiry detection
///   - BankAccount model: masked IBAN formatting
///   - BankTransaction model: credit/debit classification
///   - Category breakdown computation
///   - Monthly summary computation
///   - CHF formatting with Swiss apostrophe
///   - Bank initials extraction
///   - Supported banks constants
void main() {
  final S _s = SFr();
  // ═══════════════════════════════════════════════════════════════════════
  // 1. FINMA GATE & CONSTANTS
  // ═══════════════════════════════════════════════════════════════════════

  group('FINMA gate and constants', () {
    test('isEnabled is false (FINMA gate not cleared)', () {
      expect(OpenBankingService.isEnabled, isFalse);
    });

    test('finmaStatusMessage is non-empty French text', () {
      expect(OpenBankingService.finmaStatusMessage(_s), isNotEmpty);
      expect(OpenBankingService.finmaStatusMessage(_s), contains('consultation'));
    });

    test('supportedBanks contains 9 Swiss banks', () {
      expect(OpenBankingService.supportedBanks, hasLength(9));
    });

    test('each supported bank has id, name, and swift code', () {
      for (final bank in OpenBankingService.supportedBanks) {
        expect(bank.containsKey('id'), isTrue,
            reason: 'Bank missing id: $bank');
        expect(bank.containsKey('name'), isTrue,
            reason: 'Bank missing name: $bank');
        expect(bank.containsKey('swift'), isTrue,
            reason: 'Bank missing swift: $bank');
        expect(bank['swift']!.length, greaterThanOrEqualTo(8),
            reason: 'SWIFT code too short for ${bank["name"]}');
      }
    });

    test('supportedBanks includes major Swiss banks', () {
      final bankIds =
          OpenBankingService.supportedBanks.map((b) => b['id']).toSet();
      expect(bankIds, contains('ubs'));
      expect(bankIds, contains('postfinance'));
      expect(bankIds, contains('raiffeisen'));
      expect(bankIds, contains('bcv'));
      expect(bankIds, contains('zkb'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. BANKING CONSENT MODEL
  // ═══════════════════════════════════════════════════════════════════════

  group('BankingConsent', () {
    BankingConsent makeConsent({
      required Duration expiresIn,
      bool isRevoked = false,
    }) {
      final now = DateTime.now();
      return BankingConsent(
        consentId: 'test-consent',
        bankId: 'ubs',
        bankName: 'UBS',
        scopes: ['accounts', 'balances', 'transactions'],
        grantedAt: now.subtract(const Duration(days: 30)),
        expiresAt: now.add(expiresIn),
        isRevoked: isRevoked,
      );
    }

    test('isActive returns true for non-revoked, non-expired consent', () {
      final consent = makeConsent(expiresIn: const Duration(days: 30));
      expect(consent.isActive, isTrue);
    });

    test('isActive returns false for revoked consent', () {
      final consent =
          makeConsent(expiresIn: const Duration(days: 30), isRevoked: true);
      expect(consent.isActive, isFalse);
    });

    test('isActive returns false for expired consent', () {
      final consent = makeConsent(expiresIn: const Duration(days: -1));
      expect(consent.isActive, isFalse);
    });

    test('isExpiringSoon returns true when 0-7 days remain', () {
      final consent = makeConsent(expiresIn: const Duration(days: 5));
      expect(consent.isExpiringSoon, isTrue);
    });

    test('isExpiringSoon returns false when more than 7 days remain', () {
      final consent = makeConsent(expiresIn: const Duration(days: 30));
      expect(consent.isExpiringSoon, isFalse);
    });

    test('isExpiringSoon returns false for revoked consent', () {
      final consent =
          makeConsent(expiresIn: const Duration(days: 3), isRevoked: true);
      expect(consent.isExpiringSoon, isFalse);
    });

    test('statusKey returns "active" for healthy consent', () {
      final consent = makeConsent(expiresIn: const Duration(days: 30));
      expect(consent.statusKey, equals('active'));
    });

    test('statusKey returns "expiring_soon" for consent near expiry', () {
      final consent = makeConsent(expiresIn: const Duration(days: 5));
      expect(consent.statusKey, equals('expiring_soon'));
    });

    test('statusKey returns "expired" for past-expiry consent', () {
      final consent = makeConsent(expiresIn: const Duration(days: -1));
      expect(consent.statusKey, equals('expired'));
    });

    test('statusKey returns "revoked" even if would otherwise be active', () {
      final consent =
          makeConsent(expiresIn: const Duration(days: 30), isRevoked: true);
      expect(consent.statusKey, equals('revoked'));
    });

    test('revoke() returns a new consent with isRevoked=true', () {
      final consent = makeConsent(expiresIn: const Duration(days: 30));
      expect(consent.isRevoked, isFalse);

      final revoked = consent.revoke();
      expect(revoked.isRevoked, isTrue);
      expect(revoked.consentId, equals(consent.consentId));
      expect(revoked.bankId, equals(consent.bankId));
      expect(revoked.bankName, equals(consent.bankName));
      expect(revoked.scopes, equals(consent.scopes));
      expect(revoked.grantedAt, equals(consent.grantedAt));
      expect(revoked.expiresAt, equals(consent.expiresAt));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. BANK ACCOUNT MODEL
  // ═══════════════════════════════════════════════════════════════════════

  group('BankAccount', () {
    test('maskedIban masks middle portion of a standard IBAN', () {
      final account = BankAccount(
        accountId: 'acc-1',
        bankId: 'ubs',
        bankName: 'UBS',
        accountName: 'Compte courant',
        iban: 'CH93 0076 2011 6238 5295 7',
        balance: 8450.0,
        lastSync: DateTime.now(),
      );
      final masked = account.maskedIban;
      expect(masked.startsWith('CH93'), isTrue);
      expect(masked.endsWith('95 7'), isTrue);
      expect(masked, contains('\u2022\u2022\u2022\u2022'));
    });

    test('maskedIban returns raw IBAN when length < 8', () {
      final account = BankAccount(
        accountId: 'acc-2',
        bankId: 'test',
        bankName: 'Test',
        accountName: 'Test',
        iban: 'CH12345',
        balance: 0.0,
        lastSync: DateTime.now(),
      );
      expect(account.maskedIban, equals('CH12345'));
    });

    test('default currency is CHF', () {
      final account = BankAccount(
        accountId: 'acc-3',
        bankId: 'test',
        bankName: 'Test',
        accountName: 'Test',
        iban: 'CH1234567890',
        balance: 1000.0,
        lastSync: DateTime.now(),
      );
      expect(account.currency, equals('CHF'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. BANK TRANSACTION MODEL
  // ═══════════════════════════════════════════════════════════════════════

  group('BankTransaction', () {
    test('positive amount is classified as credit', () {
      final tx = BankTransaction(
        transactionId: 'tx-1',
        accountId: 'acc-1',
        date: DateTime.now(),
        description: 'Salaire',
        merchant: 'Employer',
        amount: 7200.0,
        category: 'revenu',
      );
      expect(tx.isCredit, isTrue);
    });

    test('negative amount is classified as debit', () {
      final tx = BankTransaction(
        transactionId: 'tx-2',
        accountId: 'acc-1',
        date: DateTime.now(),
        description: 'Loyer',
        merchant: 'Regie',
        amount: -1850.0,
        category: 'logement',
      );
      expect(tx.isCredit, isFalse);
    });

    test('zero amount is classified as credit', () {
      final tx = BankTransaction(
        transactionId: 'tx-3',
        accountId: 'acc-1',
        date: DateTime.now(),
        description: 'Adjustment',
        merchant: 'Bank',
        amount: 0.0,
        category: 'divers',
      );
      expect(tx.isCredit, isTrue);
    });

    test('default categoryIcon is receipt', () {
      final tx = BankTransaction(
        transactionId: 'tx-4',
        accountId: 'acc-1',
        date: DateTime.now(),
        description: 'Test',
        merchant: 'Test',
        amount: -10.0,
        category: 'test',
      );
      expect(tx.categoryIcon, equals('receipt'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. MOCK DATA GENERATORS
  // ═══════════════════════════════════════════════════════════════════════

  group('Mock data generators', () {
    test('getMockAccounts returns 3 accounts', () {
      expect(OpenBankingService.getMockAccounts(_s), hasLength(3));
    });

    test('all mock accounts have Swiss IBANs starting with CH', () {
      for (final acc in OpenBankingService.getMockAccounts(_s)) {
        expect(acc.iban.startsWith('CH'), isTrue,
            reason: '${acc.accountName} IBAN should start with CH');
      }
    });

    test('getMockTransactions returns 25 transactions', () {
      expect(OpenBankingService.getMockTransactions(_s), hasLength(25));
    });

    test('mock transactions include both credits and debits', () {
      final transactions = OpenBankingService.getMockTransactions(_s);
      final credits = transactions.where((tx) => tx.isCredit).toList();
      final debits = transactions.where((tx) => !tx.isCredit).toList();
      expect(credits, isNotEmpty, reason: 'Should have some credits');
      expect(debits, isNotEmpty, reason: 'Should have some debits');
    });

    test('getMockConsents returns 3 consents with scopes', () {
      final consents = OpenBankingService.getMockConsents();
      expect(consents, hasLength(3));
      for (final consent in consents) {
        expect(consent.scopes, isNotEmpty);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. TOTAL BALANCE
  // ═══════════════════════════════════════════════════════════════════════

  group('Total balance', () {
    test('sums all mock account balances correctly', () {
      final total = OpenBankingService.getTotalBalance(_s);
      // 8450 + 23100 + 45000 = 76550
      expect(total, equals(76550.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. CATEGORY BREAKDOWN
  // ═══════════════════════════════════════════════════════════════════════

  group('Category breakdown', () {
    test('returns non-empty list of categories', () {
      final breakdown = OpenBankingService.computeCategoryBreakdown(_s);
      expect(breakdown, isNotEmpty);
    });

    test('percentages sum to approximately 100', () {
      final breakdown = OpenBankingService.computeCategoryBreakdown(_s);
      final totalPct = breakdown.fold(0.0, (sum, cat) => sum + cat.percentage);
      expect(totalPct, closeTo(100.0, 0.1));
    });

    test('categories are sorted by totalAmount descending', () {
      final breakdown = OpenBankingService.computeCategoryBreakdown(_s);
      for (int i = 1; i < breakdown.length; i++) {
        expect(breakdown[i].totalAmount,
            lessThanOrEqualTo(breakdown[i - 1].totalAmount));
      }
    });

    test('only debit transactions are included (no credits)', () {
      final breakdown = OpenBankingService.computeCategoryBreakdown(_s);
      final categoryNames = breakdown.map((b) => b.category).toSet();
      expect(categoryNames.contains('revenu'), isFalse,
          reason: 'Credits should not be in spending breakdown');
      expect(categoryNames.contains('epargne'), isFalse,
          reason: 'Savings transfers should not be in spending breakdown');
    });

    test('each category has positive transactionCount', () {
      final breakdown = OpenBankingService.computeCategoryBreakdown(_s);
      for (final cat in breakdown) {
        expect(cat.transactionCount, greaterThan(0),
            reason: '${cat.category} should have > 0 transactions');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 8. MONTHLY SUMMARY
  // ═══════════════════════════════════════════════════════════════════════

  group('Monthly summary', () {
    test('returns all required keys', () {
      final summary = OpenBankingService.getMonthlySummary(_s);
      expect(summary.containsKey('income'), isTrue);
      expect(summary.containsKey('expenses'), isTrue);
      expect(summary.containsKey('net'), isTrue);
      expect(summary.containsKey('savingsRate'), isTrue);
    });

    test('income equals sum of positive amounts (7200 + 500 = 7700)', () {
      final summary = OpenBankingService.getMonthlySummary(_s);
      expect(summary['income'], equals(7700.0));
    });

    test('net equals income minus expenses', () {
      final summary = OpenBankingService.getMonthlySummary(_s);
      final computed = summary['income']! - summary['expenses']!;
      expect(summary['net'], closeTo(computed, 0.01));
    });

    test('savingsRate is between 0 and 100', () {
      final summary = OpenBankingService.getMonthlySummary(_s);
      expect(summary['savingsRate']!, greaterThanOrEqualTo(0.0));
      expect(summary['savingsRate']!, lessThanOrEqualTo(100.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 9. CHF FORMATTING
  // ═══════════════════════════════════════════════════════════════════════

  group('CHF formatting', () {
    test('formats small amount without thousands separator', () {
      expect(OpenBankingService.formatChf(450.35), equals('CHF\u00A0450.35'));
    });

    test('formats amount with Swiss apostrophe', () {
      expect(
          OpenBankingService.formatChf(8450.00), equals("CHF\u00A08'450.00"));
    });

    test('formats large amount with multiple apostrophes', () {
      expect(OpenBankingService.formatChf(1234567.89),
          equals("CHF\u00A01'234'567.89"));
    });

    test('formats negative amount with minus sign', () {
      expect(OpenBankingService.formatChf(-1850.00),
          equals("CHF\u00A0-1'850.00"));
    });

    test('formats zero correctly', () {
      expect(OpenBankingService.formatChf(0.0), equals('CHF\u00A00.00'));
    });

    test('showDecimals=false omits decimal part', () {
      expect(OpenBankingService.formatChf(8450.35, showDecimals: false),
          equals("CHF\u00A08'450"));
    });

    test('formats exactly 1000 with apostrophe', () {
      expect(
          OpenBankingService.formatChf(1000.0), equals("CHF\u00A01'000.00"));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 10. BANK INITIALS
  // ═══════════════════════════════════════════════════════════════════════

  group('Bank initials', () {
    test('single word bank takes first 2 letters uppercased', () {
      expect(OpenBankingService.getBankInitials('UBS'), equals('UB'));
    });

    test('two-word bank takes first letter of each word', () {
      expect(OpenBankingService.getBankInitials('Credit Suisse'), equals('CS'));
    });

    test('single char bank name returns single char', () {
      expect(OpenBankingService.getBankInitials('X'), equals('X'));
    });

    test('three-word bank uses only first two initials', () {
      expect(OpenBankingService.getBankInitials('Banque Cantonale Vaudoise'),
          equals('BC'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 11. CATEGORY BREAKDOWN MODEL
  // ═══════════════════════════════════════════════════════════════════════

  group('CategoryBreakdown model', () {
    test('stores all fields correctly', () {
      const cb = CategoryBreakdown(
        category: 'alimentation',
        totalAmount: 523.70,
        transactionCount: 8,
        percentage: 18.5,
      );
      expect(cb.category, equals('alimentation'));
      expect(cb.totalAmount, equals(523.70));
      expect(cb.transactionCount, equals(8));
      expect(cb.percentage, equals(18.5));
    });
  });
}
