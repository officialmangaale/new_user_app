/// The rule deciding whether a location is allowed for the current session.
///
/// Extracted from the router so it can be tested directly: exercising it
/// through the widget tree would mean building real screens that fetch over
/// the network.
library;

/// Screens whose only purpose is to get an unauthenticated visitor signed in.
///
/// `/otp` is deliberately absent. It becomes authenticated part-way through
/// its own flow and then chooses its own destination — `/setup` for a new
/// customer, or the `returnTo` the user came from, such as `/checkout`.
/// Redirecting it on the session change would strand new users in onboarding
/// and lose the intent of a login started from the cart.
///
/// `/` is absent too, so the splash screen keeps its own timing.
const Set<String> authEntryRoutes = {'/welcome', '/login'};

/// Returns the location to redirect to, or null to allow [location].
///
/// Guests are deliberately not redirected anywhere: they browse freely, and
/// protected actions prompt for login at the point of action, which is the
/// app's existing pattern.
String? authRedirect({
  required bool sessionLoaded,
  required bool authenticated,
  required String location,
}) {
  // While the stored session is still being read every answer would be a
  // guess, and guessing "signed out" is what briefly shows a login screen to
  // someone who is signed in.
  if (!sessionLoaded) return null;

  if (authenticated && authEntryRoutes.contains(location)) {
    return '/home';
  }
  return null;
}
