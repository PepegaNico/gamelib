/// Firebase project identifiers. Not secret — Firebase's client-side config
/// is always shipped inside the app; the actual access boundary is the
/// Firestore security rules plus per-user Authentication, not these values.
/// From Firebase Console → Project settings → General.
class FirebaseConfig {
  static const projectId = 'gamelib-34855';
  static const webApiKey = 'AIzaSyD4gVlFOnjA6qu5GZyW0bvcNobMb-z7kMU';
}
