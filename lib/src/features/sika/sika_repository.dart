import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../core/api_service.dart';
import 'models.dart';

/// Custom exception for Sika API errors with error codes
class SikaApiException implements Exception {
  final String message;
  final String? errorCode;
  final int? statusCode;

  SikaApiException(this.message, {this.errorCode, this.statusCode});

  bool get isInsufficientBalance => 
      errorCode == 'INSUFFICIENT_PBG_BALANCE' || 
      errorCode == 'INSUFFICIENT_BALANCE' ||
      message.toLowerCase().contains('insufficient');

  bool get isPbgError => errorCode == 'PBG_ERROR';

  @override
  String toString() => 'SikaApiException: $message (code: $errorCode)';
}

/// Laravel `JsonResource::collection()` often JSON-encodes as `{ "data": [...] }`
/// even when nested under another `data` key. Accept both raw lists and that shape.
List<dynamic> _coerceResourceList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) return raw;
  if (raw is Map) {
    final inner = raw['data'];
    if (inner is List) return inner;
  }
  return [];
}

class SikaRepository {
  final ApiService _api;
  static const _uuid = Uuid();

  SikaRepository(this._api);

  String _generateIdempotencyKey(String prefix) {
    return '${prefix}_${_uuid.v4()}';
  }

  /// Extracts error info from DioException response and throws SikaApiException
  Never _handleApiError(DioException e) {
    final data = e.response?.data;
    String message = 'An error occurred';
    String? errorCode;

    if (data is Map<String, dynamic>) {
      message = data['message'] as String? ?? message;
      errorCode = data['error_code'] as String?;
    }

    throw SikaApiException(
      message,
      errorCode: errorCode,
      statusCode: e.response?.statusCode,
    );
  }

  Future<List<SikaPack>> getPacks() async {
    final response = await _api.get('/sika/packs');
    final list = _coerceResourceList(response.data['data']);
    return list.map((json) => SikaPack.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<SikaPack> getPack(int packId) async {
    final response = await _api.get('/sika/packs/$packId');
    return SikaPack.fromJson(response.data['data']);
  }

  Future<({SikaWallet wallet, List<SikaLedgerEntry> recentTransactions})> getWallet() async {
    final response = await _api.get('/sika/wallet');
    final data = response.data['data'] as Map<String, dynamic>;

    final wallet = SikaWallet.fromJson(
      Map<String, dynamic>.from(data['wallet'] as Map),
    );
    final txRaw = _coerceResourceList(data['recent_transactions']);
    final transactions = txRaw
        .map(
          (json) => SikaLedgerEntry.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();

    return (wallet: wallet, recentTransactions: transactions);
  }

  Future<({List<SikaLedgerEntry> transactions, int currentPage, int lastPage, int total})> 
      getTransactions({
        int page = 1,
        int perPage = 20,
        String? type,
        String? direction,
      }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (type != null) queryParams['type'] = type;
    if (direction != null) queryParams['direction'] = direction;

    final response = await _api.get('/sika/transactions', queryParameters: queryParams);
    final data = response.data as Map<String, dynamic>;

    final list = _coerceResourceList(data['data']);
    final transactions = list
        .map(
          (json) => SikaLedgerEntry.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();

    final pagination = Map<String, dynamic>.from(data['pagination'] as Map);
    
    return (
      transactions: transactions,
      currentPage: pagination['current_page'] as int,
      lastPage: pagination['last_page'] as int,
      total: pagination['total'] as int,
    );
  }

  Future<PurchaseResult> purchasePack(int packId, {String? idempotencyKey}) async {
    final key = idempotencyKey ?? _generateIdempotencyKey('purchase');
    
    try {
      final response = await _api.post('/sika/purchase/initiate', data: {
        'pack_id': packId,
        'idempotency_key': key,
      });
      
      return PurchaseResult.fromJson(response.data['data']);
    } on DioException catch (e) {
      _handleApiError(e);
    }
  }

  Future<TransferResult> transfer({
    required int toUserId,
    required int coins,
    String? note,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _generateIdempotencyKey('transfer');
    
    try {
      final response = await _api.post('/sika/transfer', data: {
        'to_user_id': toUserId,
        'coins': coins,
        if (note != null) 'note': note,
        'idempotency_key': key,
      });
      
      return TransferResult.fromJson(response.data['data']);
    } on DioException catch (e) {
      _handleApiError(e);
    }
  }

  Future<GiftResult> gift({
    int? toUserId,
    int? postId,
    int? messageId,
    required int coins,
    String? note,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _generateIdempotencyKey('gift');
    
    try {
      final response = await _api.post('/sika/gift', data: {
        if (toUserId != null) 'to_user_id': toUserId,
        if (postId != null) 'post_id': postId,
        if (messageId != null) 'message_id': messageId,
        'coins': coins,
        if (note != null) 'note': note,
        'idempotency_key': key,
      });
      
      return GiftResult.fromJson(response.data['data']);
    } on DioException catch (e) {
      _handleApiError(e);
    }
  }
}
