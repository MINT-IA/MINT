// ────────────────────────────────────────────────────────────
//  OPEN BANKING — Phase 3+ (FINMA gate)
// ────────────────────────────────────────────────────────────
//
// Ce service est ENTIEREMENT MOCKE. isEnabled = false.
// Aucune donnee reelle n'est echangee.
// Activation prevue apres consultation reglementaire FINMA.
// Ne PAS supprimer — l'architecture est prete pour l'activation.
//
// Compliance: nLPD consent, read-only, FINMA gate,
// no banned terms ("garanti", "assure" in guarantee sense,
// "certain").
// ────────────────────────────────────────────────────────────

/// Represents a bank connection consent (nLPD-compliant).
class BankingConsent {
  final String consentId;
  final String bankId;
  final String bankName;
  final List<String> scopes; // ["accounts", "balances", "transactions"]
  final DateTime grantedAt;
  final DateTime expiresAt; // 90 days max
  final bool isRevoked;

  const BankingConsent({
    required this.consentId,
    required this.bankId,
    required this.bankName,
    required this.scopes,
    required this.grantedAt,
    required this.expiresAt,
    this.isRevoked = false,
  });

  /// Whether the consent is currently active (not revoked and not expired).
  bool get isActive => !isRevoked && DateTime.now().isBefore(expiresAt);

  /// Whether the consent is expiring within the next 7 days.
  bool get isExpiringSoon {
    if (isRevoked) return false;
    final daysLeft = expiresAt.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 7;
  }

  /// Status label: "active", "expiring_soon", "expired", "revoked".
  String get statusKey {
    if (isRevoked) return 'revoked';
    if (DateTime.now().isAfter(expiresAt)) return 'expired';
    if (isExpiringSoon) return 'expiring_soon';
    return 'active';
  }

  /// Return a copy with isRevoked set to true.
  BankingConsent revoke() => BankingConsent(
        consentId: consentId,
        bankId: bankId,
        bankName: bankName,
        scopes: scopes,
        grantedAt: grantedAt,
        expiresAt: expiresAt,
        isRevoked: true,
      );
}

/// A mock bank account.
class BankAccount {
  final String accountId;
  final String bankId;
  final String bankName;
  final String accountName;
  final String iban;
  final double balance;
  final String currency;
  final DateTime lastSync;

  const BankAccount({
    required this.accountId,
    required this.bankId,
    required this.bankName,
    required this.accountName,
    required this.iban,
    required this.balance,
    this.currency = 'CHF',
    required this.lastSync,
  });

  /// Masked IBAN (e.g. CH93 •••• 5297).
  String get maskedIban {
    if (iban.length < 8) return iban;
    final prefix = iban.substring(0, 4);
    final suffix = iban.substring(iban.length - 4);
    return '$prefix \u2022\u2022\u2022\u2022 $suffix';
  }
}

/// A single transaction.
class BankTransaction {
  final String transactionId;
  final String accountId;
  final DateTime date;
  final String description;
  final String merchant;
  final double amount; // positive = credit, negative = debit
  final String category;
  final String categoryIcon;

  const BankTransaction({
    required this.transactionId,
    required this.accountId,
    required this.date,
    required this.description,
    required this.merchant,
    required this.amount,
    required this.category,
    this.categoryIcon = 'receipt',
  });

  bool get isCredit => amount >= 0;
}

/// Spending category breakdown for a date range.
class CategoryBreakdown {
  final String category;
  final double totalAmount;
  final int transactionCount;
  final double percentage;

  const CategoryBreakdown({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });
}

/// Open Banking Service — all logic is local (mock data).
///
/// Behind a FINMA consultation gate. Set [isEnabled] to true
/// only after regulatory clearance.
class OpenBankingService {
  // ── FINMA Gate ──────────────────────────────────────────────

  /// Whether Open Banking is enabled (FINMA gate).
  static const bool isEnabled = false; // Set to true after FINMA consultation

  /// FINMA status message.
  static const String finmaStatusMessage =
      'Fonctionnalite en preparation \u2014 consultation reglementaire en cours.';

  // ── Supported Banks ─────────────────────────────────────────

  /// Supported banks in Switzerland (bLink/SFTI ecosystem).
  static const List<Map<String, String>> supportedBanks = [
    {'id': 'ubs', 'name': 'UBS', 'swift': 'UBSWCHZH'},
    {'id': 'postfinance', 'name': 'PostFinance', 'swift': 'POFICHBE'},
    {'id': 'raiffeisen', 'name': 'Raiffeisen', 'swift': 'RAIFCH22'},
    {
      'id': 'credit_suisse',
      'name': 'Credit Suisse (UBS)',
      'swift': 'CRESCHZZ'
    },
    {'id': 'bcv', 'name': 'BCV', 'swift': 'BCVLCH2L'},
    {'id': 'bcge', 'name': 'BCGE', 'swift': 'BCGECHGG'},
    {'id': 'zkb', 'name': 'ZKB', 'swift': 'ZKBKCHZZ'},
    {'id': 'neon', 'name': 'Neon', 'swift': 'HYPLCH22'},
    {'id': 'yuh', 'name': 'Yuh', 'swift': 'UBSWCHZH'},
  ];

  // ── Mock Accounts ───────────────────────────────────────────

  /// 3 demo accounts for the mock UI.
  static List<BankAccount> getMockAccounts() {
    final now = DateTime.now();
    return [
      BankAccount(
        accountId: 'acc-ubs-001',
        bankId: 'ubs',
        bankName: 'UBS',
        accountName: 'Compte courant',
        iban: 'CH93 0076 2011 6238 5295 7',
        balance: 8450.00,
        lastSync: now.subtract(const Duration(hours: 2)),
      ),
      BankAccount(
        accountId: 'acc-pf-002',
        bankId: 'postfinance',
        bankName: 'PostFinance',
        accountName: 'Epargne',
        iban: 'CH18 0900 0000 1234 5678 9',
        balance: 23100.00,
        lastSync: now.subtract(const Duration(hours: 5)),
      ),
      BankAccount(
        accountId: 'acc-raif-003',
        bankId: 'raiffeisen',
        bankName: 'Raiffeisen',
        accountName: '3a',
        iban: 'CH52 8080 8001 2345 6789 0',
        balance: 45000.00,
        lastSync: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  // ── Mock Transactions ───────────────────────────────────────

  /// 25 mock transactions for the last month with Swiss merchants.
  static List<BankTransaction> getMockTransactions() {
    final now = DateTime.now();
    return [
      // Salary
      BankTransaction(
        transactionId: 'tx_01',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 1),
        description: 'Salaire mensuel',
        merchant: 'Employeur SA',
        amount: 7200.00,
        category: 'revenu',
        categoryIcon: 'account_balance_wallet',
      ),
      // Rent
      BankTransaction(
        transactionId: 'tx_02',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 1),
        description: 'Loyer mensuel',
        merchant: 'Regie immobiliere',
        amount: -1850.00,
        category: 'logement',
        categoryIcon: 'home',
      ),
      // Health insurance
      BankTransaction(
        transactionId: 'tx_03',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 2),
        description: 'Prime assurance maladie',
        merchant: 'CSS Assurance',
        amount: -380.50,
        category: 'assurances',
        categoryIcon: 'health_and_safety',
      ),
      // Telecom
      BankTransaction(
        transactionId: 'tx_04',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 3),
        description: 'Abonnement mobile + internet',
        merchant: 'Swisscom',
        amount: -89.90,
        category: 'telecom',
        categoryIcon: 'phone_android',
      ),
      // Transport
      BankTransaction(
        transactionId: 'tx_05',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 3),
        description: 'AG/Abonnement general',
        merchant: 'CFF/SBB',
        amount: -340.00,
        category: 'transport',
        categoryIcon: 'train',
      ),
      // Groceries
      BankTransaction(
        transactionId: 'tx_06',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 4),
        description: 'Courses alimentaires',
        merchant: 'Migros',
        amount: -87.35,
        category: 'alimentation',
        categoryIcon: 'shopping_cart',
      ),
      BankTransaction(
        transactionId: 'tx_07',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 5),
        description: 'Courses alimentaires',
        merchant: 'Coop',
        amount: -63.20,
        category: 'alimentation',
        categoryIcon: 'shopping_cart',
      ),
      BankTransaction(
        transactionId: 'tx_08',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 7),
        description: 'Courses alimentaires',
        merchant: 'Denner',
        amount: -42.10,
        category: 'alimentation',
        categoryIcon: 'shopping_cart',
      ),
      // Energy
      BankTransaction(
        transactionId: 'tx_09',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 5),
        description: 'Electricite + gaz',
        merchant: 'SIG (Services Industriels)',
        amount: -125.00,
        category: 'energie',
        categoryIcon: 'bolt',
      ),
      // Transport local
      BankTransaction(
        transactionId: 'tx_10',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 6),
        description: 'Abonnement TPG',
        merchant: 'TPG',
        amount: -70.00,
        category: 'transport',
        categoryIcon: 'directions_bus',
      ),
      // Restaurant/Loisirs
      BankTransaction(
        transactionId: 'tx_11',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 7),
        description: 'Restaurant',
        merchant: 'Cafe du Soleil',
        amount: -45.50,
        category: 'loisirs',
        categoryIcon: 'restaurant',
      ),
      BankTransaction(
        transactionId: 'tx_12',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 8),
        description: 'Cinema',
        merchant: 'Pathe Geneve',
        amount: -24.00,
        category: 'loisirs',
        categoryIcon: 'movie',
      ),
      // Groceries week 2
      BankTransaction(
        transactionId: 'tx_13',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 10),
        description: 'Courses alimentaires',
        merchant: 'Migros',
        amount: -92.60,
        category: 'alimentation',
        categoryIcon: 'shopping_cart',
      ),
      BankTransaction(
        transactionId: 'tx_14',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 12),
        description: 'Courses alimentaires',
        merchant: 'Lidl',
        amount: -54.80,
        category: 'alimentation',
        categoryIcon: 'shopping_cart',
      ),
      // Health
      BankTransaction(
        transactionId: 'tx_15',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 11),
        description: 'Pharmacie',
        merchant: 'Pharmacie Amavita',
        amount: -38.90,
        category: 'sante',
        categoryIcon: 'local_pharmacy',
      ),
      // Savings
      BankTransaction(
        transactionId: 'tx_16',
        accountId: 'acc-pf-002',
        date: DateTime(now.year, now.month, 1),
        description: 'Virement epargne mensuel',
        merchant: 'Virement interne',
        amount: 500.00,
        category: 'epargne',
        categoryIcon: 'savings',
      ),
      // More groceries
      BankTransaction(
        transactionId: 'tx_17',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 15),
        description: 'Courses alimentaires',
        merchant: 'Coop',
        amount: -78.45,
        category: 'alimentation',
        categoryIcon: 'shopping_cart',
      ),
      BankTransaction(
        transactionId: 'tx_18',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 17),
        description: 'Courses alimentaires',
        merchant: 'Migros',
        amount: -105.20,
        category: 'alimentation',
        categoryIcon: 'shopping_cart',
      ),
      // Loisirs
      BankTransaction(
        transactionId: 'tx_19',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 16),
        description: 'Fitness',
        merchant: 'Fitness Park',
        amount: -59.00,
        category: 'loisirs',
        categoryIcon: 'fitness_center',
      ),
      // Diverse
      BankTransaction(
        transactionId: 'tx_20',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 18),
        description: 'Coiffeur',
        merchant: 'Salon Beaute',
        amount: -55.00,
        category: 'divers',
        categoryIcon: 'content_cut',
      ),
      // More groceries
      BankTransaction(
        transactionId: 'tx_21',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 20),
        description: 'Courses alimentaires',
        merchant: 'Denner',
        amount: -38.70,
        category: 'alimentation',
        categoryIcon: 'shopping_cart',
      ),
      BankTransaction(
        transactionId: 'tx_22',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 22),
        description: 'Courses alimentaires',
        merchant: 'Migros',
        amount: -96.30,
        category: 'alimentation',
        categoryIcon: 'shopping_cart',
      ),
      // Impots
      BankTransaction(
        transactionId: 'tx_23',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 15),
        description: 'Acompte impots',
        merchant: 'AFC Canton de Geneve',
        amount: -850.00,
        category: 'impots',
        categoryIcon: 'receipt_long',
      ),
      // Assurance complementaire
      BankTransaction(
        transactionId: 'tx_24',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 5),
        description: 'Assurance complementaire',
        merchant: 'Helsana',
        amount: -65.00,
        category: 'assurances',
        categoryIcon: 'health_and_safety',
      ),
      // Restaurant
      BankTransaction(
        transactionId: 'tx_25',
        accountId: 'acc-ubs-001',
        date: DateTime(now.year, now.month, 21),
        description: 'Restaurant midi',
        merchant: 'Manora Geneve',
        amount: -18.50,
        category: 'loisirs',
        categoryIcon: 'restaurant',
      ),
    ];
  }

  // ── Mock Consents ───────────────────────────────────────────

  /// Demo consents for the mock UI.
  static List<BankingConsent> getMockConsents() {
    final now = DateTime.now();
    return [
      BankingConsent(
        consentId: 'consent_ubs_01',
        bankId: 'ubs',
        bankName: 'UBS',
        scopes: ['accounts', 'balances', 'transactions'],
        grantedAt: now.subtract(const Duration(days: 45)),
        expiresAt: now.add(const Duration(days: 45)),
      ),
      BankingConsent(
        consentId: 'consent_pf_01',
        bankId: 'postfinance',
        bankName: 'PostFinance',
        scopes: ['accounts', 'balances'],
        grantedAt: now.subtract(const Duration(days: 80)),
        expiresAt: now.add(const Duration(days: 10)),
      ),
      BankingConsent(
        consentId: 'consent_raif_01',
        bankId: 'raiffeisen',
        bankName: 'Raiffeisen',
        scopes: ['accounts', 'balances', 'transactions'],
        grantedAt: now.subtract(const Duration(days: 30)),
        expiresAt: now.add(const Duration(days: 60)),
      ),
    ];
  }

  // ── Category Breakdown ──────────────────────────────────────

  /// Compute spending by category for a given date range.
  static List<CategoryBreakdown> computeCategoryBreakdown({
    DateTime? from,
    DateTime? to,
  }) {
    final transactions = getMockTransactions();
    final now = DateTime.now();
    final startDate = from ?? DateTime(now.year, now.month, 1);
    final endDate = to ?? now;

    // Filter to debits in range
    final filtered = transactions.where((tx) =>
        tx.amount < 0 &&
        !tx.date.isBefore(startDate) &&
        !tx.date.isAfter(endDate));

    // Group by category
    final Map<String, double> totals = {};
    final Map<String, int> counts = {};
    double grandTotal = 0;

    for (final tx in filtered) {
      final cat = tx.category;
      totals[cat] = (totals[cat] ?? 0) + tx.amount.abs();
      counts[cat] = (counts[cat] ?? 0) + 1;
      grandTotal += tx.amount.abs();
    }

    // Build sorted list
    final breakdown = totals.entries.map((e) {
      return CategoryBreakdown(
        category: e.key,
        totalAmount: e.value,
        transactionCount: counts[e.key] ?? 0,
        percentage: grandTotal > 0 ? (e.value / grandTotal * 100) : 0,
      );
    }).toList();

    breakdown.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return breakdown;
  }

  // ── Monthly Summary ─────────────────────────────────────────

  /// Compute total income and expenses for the current month.
  static Map<String, double> getMonthlySummary() {
    final transactions = getMockTransactions();
    double income = 0;
    double expenses = 0;

    for (final tx in transactions) {
      if (tx.amount >= 0) {
        income += tx.amount;
      } else {
        expenses += tx.amount.abs();
      }
    }

    return {
      'income': income,
      'expenses': expenses,
      'net': income - expenses,
      'savingsRate': income > 0 ? ((income - expenses) / income * 100) : 0,
    };
  }

  /// Compute total balance across all mock accounts.
  static double getTotalBalance() {
    return getMockAccounts().fold(0.0, (sum, acc) => sum + acc.balance);
  }

  // ── Formatting Helpers ──────────────────────────────────────

  /// Format CHF with Swiss apostrophe (e.g. 8'450.35).
  static String formatChf(double value, {bool showDecimals = true}) {
    final isNegative = value < 0;
    final abs = value.abs();
    final intPart = abs.truncate();
    final decPart = ((abs - intPart) * 100).round();

    final intStr = intPart.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < intStr.length; i++) {
      if (i > 0 && (intStr.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(intStr[i]);
    }

    final prefix = isNegative ? '-' : '';
    if (showDecimals) {
      final decStr = decPart.toString().padLeft(2, '0');
      return 'CHF\u00A0$prefix${buffer.toString()}.$decStr';
    }
    return 'CHF\u00A0$prefix${buffer.toString()}';
  }

  /// Get bank initials for avatar (e.g. "UBS" -> "UB", "PostFinance" -> "PF").
  static String getBankInitials(String bankName) {
    final words = bankName.split(' ');
    if (words.length == 1) {
      return bankName.substring(0, bankName.length >= 2 ? 2 : bankName.length)
          .toUpperCase();
    }
    return words.map((w) => w[0]).take(2).join().toUpperCase();
  }
}
