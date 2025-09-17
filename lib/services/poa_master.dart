/// A simple service to manage POA master data.
///
/// For now, this is just a placeholder list of client IDs
/// that have a valid POA on file. Later you can:
///   - Load this list from a CSV/Excel
///   - Sync from IRS CAF API (when available)
///   - Or manage through your app’s admin tools

class PoaMasterService {
  // TODO: Replace this with real data loading
  static final Set<String> _poaClientIds = {
    "ABCD1234",
    "XYZ1234",
  };

  /// Returns true if the given clientId has a POA on file
  static bool hasPoa(String clientId) {
    return _poaClientIds.contains(clientId.toUpperCase());
  }

  /// Adds a clientId to the master list (temporary, in-memory)
  static void addPoa(String clientId) {
    _poaClientIds.add(clientId.toUpperCase());
  }

  /// Removes a clientId from the master list (temporary, in-memory)
  static void removePoa(String clientId) {
    _poaClientIds.remove(clientId.toUpperCase());
  }

  /// Returns all clientIds in the master list
  static List<String> allPoaClientIds() {
    return _poaClientIds.toList();
  }
}
