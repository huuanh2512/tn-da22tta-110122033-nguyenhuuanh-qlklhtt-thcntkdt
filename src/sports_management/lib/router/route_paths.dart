abstract final class RoutePaths {
  // Root
  static const String splash = '/';
  static const String splashName = 'splash';

  // Auth
  static const String signIn = '/sign-in';
  static const String signInName = 'sign-in';
  static const String signUp = '/sign-up';
  static const String signUpName = 'sign-up';
  static const String resetPassword = '/reset-password';
  static const String resetPasswordName = 'reset-password';

  // Main
  static const String home = '/home';

  // Booking
  static const String bookingList = '/booking';
  static const String bookingDetail = '/booking/:id';
  static String bookingDetailPath(String id) => '/booking/$id';

  // Court
  static const String courtList = '/court';
  static const String courtDetail = '/court/:id';
  static String courtDetailPath(String id) => '/court/$id';

  // Facility
  static const String facilityList = '/facility';
  static const String facilityDetail = '/facility/:id';
  static String facilityDetailPath(String id) => '/facility/$id';

  // Payment
  static const String paymentList = '/payment';
  static const String paymentDetail = '/payment/:id';
  static String paymentDetailPath(String id) => '/payment/$id';

  // User management
  static const String userList = '/user';
  static const String userDetail = '/user/:id';
  static String userDetailPath(String id) => '/user/$id';

  // Notification
  static const String notifications = '/notification';

  // Profile
  static const String profile = '/profile';
}