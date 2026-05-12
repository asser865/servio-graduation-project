import 'api_config.dart';

class ApiEndpoints {
  const ApiEndpoints._();

  static const String baseUrl = ApiConfig.baseUrl;

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static String resetPassword(String token) => '/auth/reset-password/$token';
  static const String authMe = '/auth/me';

  static const String usersMe = '/users/me';
  static const String usersMeAddresses = '/users/me/addresses';
  static String usersMeAddress(String id) => '/users/me/addresses/$id';
  static const String usersMeEmail = '/users/me/email';
  static const String usersMePassword = '/users/me/password';
  static const String usersMeAvailable = '/users/me/available';
  static const String usersMeAvailability = '/users/me/availability';
  static const String usersMeBlockedDates = '/users/me/blocked-dates';
  static const String workers = '/users/workers';
  static String workerById(String id) => '/users/workers/$id';

  static const String services = '/services';
  static String serviceById(String id) => '/services/$id';
  static String techniciansForService(String serviceId) =>
      '/services/$serviceId/technicians';

  static const String bookings = '/bookings';
  static const String myBookings = '/bookings/my';
  static const String workerBookings = '/bookings/worker';
  static String bookingById(String id) => '/bookings/$id';
  static String bookingStatus(String id) => '/bookings/$id/status';
  static String workerBookedSlots(String workerId, String date) =>
      '/bookings/worker/$workerId/slots?date=$date';

  static const String aiRecommend = '/ai/recommend';

  static const String reviews = '/reviews';
  static String workerReviews(String workerId) => '/reviews/worker/$workerId';

  static const String conversations = '/messages/conversations';
  static const String startConversation = '/messages/conversations/start';
  static const String unreadMessages = '/messages/unread';
  static const String messages = '/messages';
  static String messagesForConversation(String conversationId) =>
      '/messages/conversations/$conversationId';
  static String messagesForBooking(String bookingId) => '/messages/$bookingId';

  static const String notify = '/notify';

  static String paymentEarnings(String period) =>
      '/payments/earnings?period=$period';

  static const String paymentSettings = '/payments/settings';
  static const String savedCards = '/saved-cards';
  static String savedCard(String id) => '/saved-cards/$id';
  static String defaultSavedCard(String id) => '/saved-cards/$id/default';
}
