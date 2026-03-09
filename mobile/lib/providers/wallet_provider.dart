import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int dropCreateFee = 2000000;  // 0.002 SOL
const int claimFee      = 1000000;  // 0.001 SOL
const _ch = MethodChannel('com.streetdrop/wallet');

enum WalletStatus { disconnected, connecting, connected, error }
enum WalletType   { seedVault, phantom, solflare, unknown }

class WalletState {
  final WalletStatus status;
  final String?      address, error;
  final WalletType   walletType;

  const WalletState({
    this.status     = WalletStatus.disconnected,
    this.address,
    this.error,
    this.walletType = WalletType.unknown,
  });

  WalletState copyWith({WalletStatus? status, String? address, String? error, WalletType? walletType}) =>
      WalletState(
        status:     status     ?? this.status,
        address:    address    ?? this.address,
        error:      error,
        walletType: walletType ?? this.walletType,
      );

  bool   get isConnected  => status == WalletStatus.connected && address != null;
  String get shortAddress => address == null ? '' : '${address!.substring(0,4)}...${address!.substring(address!.length-4)}';
  String get walletLabel  => switch (walletType) {
    WalletType.seedVault => 'Seed Vault',
    WalletType.phantom   => 'Phantom',
    WalletType.solflare  => 'Solflare',
    WalletType.unknown   => 'Wallet',
  };
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState()) { _tryAutoConnect(); }

  Future<void> _tryAutoConnect() async {
    try {
      final res = await _ch.invokeMethod<Map>('checkSeedVault');
      if (res != null && res['available'] == true) {
        state = state.copyWith(
          status:     WalletStatus.connected,
          address:    res['address'] as String,
          walletType: WalletType.seedVault,
        );
      }
    } catch (_) {}
  }

  Future<void> connect() async {
    if (state.isConnected) return;
    state = state.copyWith(status: WalletStatus.connecting, error: null);
    try {
      final res = await _ch.invokeMethod<Map>('connectWallet', {
        'cluster': 'devnet',
        'appName': 'StreetDrop',
        'appUri':  'https://streetdrop.xyz',
        'iconUri': 'https://streetdrop.xyz/icon.png',
      });
      if (res == null || res['address'] == null) throw Exception('No address returned');
      final name = res['walletName']?.toString().toLowerCase() ?? '';
      final type = name.contains('phantom')   ? WalletType.phantom
                 : name.contains('solflare')  ? WalletType.solflare
                 : name.contains('seed')      ? WalletType.seedVault
                 : WalletType.unknown;
      state = state.copyWith(
        status:     WalletStatus.connected,
        address:    res['address'] as String,
        walletType: type,
        error:      null,
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'USER_CANCELLED':
          state = state.copyWith(status: WalletStatus.disconnected);
        case 'NO_WALLET':
          state = state.copyWith(status: WalletStatus.error, error: 'no_wallet');
        default:
          state = state.copyWith(status: WalletStatus.error, error: e.message);
      }
    } on MissingPluginException {
      state = state.copyWith(status: WalletStatus.error, error: 'MWA not available on emulator. Use a real Solana Android device.');
    }
  }

  Future<String> signAndSendFee(int lamports) async {
    if (!state.isConnected) throw Exception('Wallet not connected');
    try {
      final res = await _ch.invokeMethod<Map>('signAndSendFee', {
        'fromWallet': state.address,
        'lamports':   lamports,
        'rpcUrl':     'https://api.devnet.solana.com',
      });
      if (res == null || res['txSignature'] == null) throw Exception('No signature');
      return res['txSignature'] as String;
    } on MissingPluginException {
      await Future.delayed(const Duration(milliseconds: 600));
      return 'DEVTEST${DateTime.now().millisecondsSinceEpoch}FAKEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    }
  }

  void disconnect() => state = const WalletState();
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) => WalletNotifier());
