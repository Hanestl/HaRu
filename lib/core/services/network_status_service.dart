import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkClass { wifi, mobile, offline, other }

abstract interface class NetworkStatusService {
  Future<NetworkClass> current();
  Stream<NetworkClass> get onStatusChanged;
}

final class ConnectivityNetworkStatusService implements NetworkStatusService {
  ConnectivityNetworkStatusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static NetworkClass classify(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return NetworkClass.wifi;
    }
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.satellite)) {
      return NetworkClass.mobile;
    }
    if (results.isEmpty ||
        results.every((item) => item == ConnectivityResult.none)) {
      return NetworkClass.offline;
    }
    return NetworkClass.other;
  }

  @override
  Future<NetworkClass> current() async {
    final results = await _connectivity.checkConnectivity();
    return classify(results);
  }

  @override
  Stream<NetworkClass> get onStatusChanged =>
      _connectivity.onConnectivityChanged.map(classify).distinct();
}
