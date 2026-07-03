class SikaPack {
  final int id;
  final String name;
  final String? description;
  final double priceGhs;
  final int coins;
  final int bonusCoins;
  final int totalCoins;
  final double coinsPerGhs;
  final String? icon;
  final bool isPopular;

  SikaPack({
    required this.id,
    required this.name,
    this.description,
    required this.priceGhs,
    required this.coins,
    required this.bonusCoins,
    required this.totalCoins,
    required this.coinsPerGhs,
    this.icon,
    this.isPopular = false,
  });

  factory SikaPack.fromJson(Map<String, dynamic> json) {
    return SikaPack(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      priceGhs: (json['price_ghs'] as num).toDouble(),
      coins: json['coins'] as int,
      bonusCoins: json['bonus_coins'] as int? ?? 0,
      totalCoins: json['total_coins'] as int,
      coinsPerGhs: (json['coins_per_ghs'] as num?)?.toDouble() ?? 0,
      icon: json['icon'] as String?,
      isPopular: json['is_popular'] as bool? ?? false,
    );
  }
}

class SikaWallet {
  final int id;
  final int userId;
  final int balance;
  final String formattedBalance;
  final String status;
  final bool canTransact;
  final DateTime createdAt;

  SikaWallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.formattedBalance,
    required this.status,
    required this.canTransact,
    required this.createdAt,
  });

  factory SikaWallet.fromJson(Map<String, dynamic> json) {
    return SikaWallet(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      balance: json['balance'] as int,
      formattedBalance: json['formatted_balance'] as String? ?? '0',
      status: json['status'] as String,
      canTransact: json['can_transact'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SikaLedgerEntry {
  final int id;
  final String type;
  final String typeLabel;
  final String direction;
  final int coins;
  final String formattedCoins;
  final String status;
  final int? balanceAfter;
  final String? referenceType;
  final String? referenceId;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  final String createdAtHuman;

  SikaLedgerEntry({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.direction,
    required this.coins,
    required this.formattedCoins,
    required this.status,
    this.balanceAfter,
    this.referenceType,
    this.referenceId,
    this.meta,
    required this.createdAt,
    required this.createdAtHuman,
  });

  factory SikaLedgerEntry.fromJson(Map<String, dynamic> json) {
    return SikaLedgerEntry(
      id: json['id'] as int,
      type: json['type'] as String,
      typeLabel: json['type_label'] as String,
      direction: json['direction'] as String,
      coins: json['coins'] as int,
      formattedCoins: json['formatted_coins'] as String,
      status: json['status'] as String,
      balanceAfter: json['balance_after'] as int?,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdAtHuman: json['created_at_human'] as String,
    );
  }

  bool get isCredit => direction == 'CREDIT';
  bool get isDebit => direction == 'DEBIT';
}

class PurchaseResult {
  final bool success;
  final int entryId;
  final int coinsCredited;
  final int newBalance;
  final int packId;
  final String packName;
  final double priceGhs;
  final String pbgReference;
  final DateTime createdAt;

  PurchaseResult({
    required this.success,
    required this.entryId,
    required this.coinsCredited,
    required this.newBalance,
    required this.packId,
    required this.packName,
    required this.priceGhs,
    required this.pbgReference,
    required this.createdAt,
  });

  factory PurchaseResult.fromJson(Map<String, dynamic> json) {
    return PurchaseResult(
      success: json['success'] as bool? ?? true,
      entryId: json['entry_id'] as int,
      coinsCredited: json['coins_credited'] as int,
      newBalance: json['new_balance'] as int,
      packId: json['pack_id'] as int,
      packName: json['pack_name'] as String,
      priceGhs: (json['price_ghs'] as num).toDouble(),
      pbgReference: json['pbg_reference'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TransferResult {
  final bool success;
  final int entryId;
  final int coins;
  final int newBalance;
  final int toUserId;
  final String groupId;
  final DateTime createdAt;

  TransferResult({
    required this.success,
    required this.entryId,
    required this.coins,
    required this.newBalance,
    required this.toUserId,
    required this.groupId,
    required this.createdAt,
  });

  factory TransferResult.fromJson(Map<String, dynamic> json) {
    return TransferResult(
      success: json['success'] as bool? ?? true,
      entryId: json['entry_id'] as int,
      coins: json['coins'] as int,
      newBalance: json['new_balance'] as int,
      toUserId: json['to_user_id'] as int,
      groupId: json['group_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class GiftResult {
  final bool success;
  final int entryId;
  final int coins;
  final int newBalance;
  final int toUserId;
  final int? postId;
  final int? messageId;
  final String groupId;
  final DateTime createdAt;

  GiftResult({
    required this.success,
    required this.entryId,
    required this.coins,
    required this.newBalance,
    required this.toUserId,
    this.postId,
    this.messageId,
    required this.groupId,
    required this.createdAt,
  });

  factory GiftResult.fromJson(Map<String, dynamic> json) {
    return GiftResult(
      success: json['success'] as bool? ?? true,
      entryId: json['entry_id'] as int,
      coins: json['coins'] as int,
      newBalance: json['new_balance'] as int,
      toUserId: json['to_user_id'] as int,
      postId: json['post_id'] as int?,
      messageId: json['message_id'] as int?,
      groupId: json['group_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
