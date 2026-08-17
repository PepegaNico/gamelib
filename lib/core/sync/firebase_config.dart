/// Firebase project identifiers. Not secret — Firebase's client-side config
/// is always shipped inside the app; the actual access boundary is the
/// Firestore security rules plus per-user Authentication, not these values.
/// From Firebase Console → Project settings → General.
class FirebaseConfig {
  static const projectId = 'REPLACE_WITH_PROJECT_ID';
  static const webApiKey = 'REPLACE_WITH_WEB_API_KEY';
}
