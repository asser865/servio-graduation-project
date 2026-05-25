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

  static const String aiRecommend = '/mobile/ai/recommend';
  static const String aiAnalyzeRoom = '/mobile/ai/analyze-room';

  static const String reviews = '/reviews';
  static String workerReviews(String workerId) => '/reviews/worker/$workerId';

  static const String conversations = '/messages/conversations';
  static const String startConversation = '/messages/conversations/start';
  static const String unreadMessages = '/messages/unread';
  static const String messages = '/messages';
  static String messagesForConversation(String conversationId) =>
      '/messages/conversations/$conversationId';
  static String conversation(String conversationId) =>
      '/messages/conversations/$conversationId';
  static String messagesForBooking(String bookingId) => '/messages/$bookingId';

  static const String notify = '/notify';

  // ── In-app notifications ─────────────────────────────────────────────────
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationMarkRead(String id) => '/notifications/$id/read';
  static String notificationDelete(String id) => '/notifications/$id';

  static String paymentEarnings(String period) =>
      '/payments/earnings?period=$period';

  static const String paymentSettings = '/payments/settings';

  // ── Payments v2: debts, settlements, payouts, credits, invoices ──────────
  static const String paymentMyDebts = '/payments/my-debts/v2';
  static const String paymentSettleDebts = '/payments/my-debts/settle';
  static const String paymentMySettlements = '/payments/my-settlements';
  static const String paymentPayoutRequest = '/payments/payout-request';
  static const String paymentMyPayouts = '/payments/my-payouts';
  static const String paymentMeCredits = '/payments/me/credits';
  static const String paymentMeInvoices = '/payments/me/invoices';
  static String paymentReceipt(String id) => '/payments/$id/receipt';
  static const String paymentMeHistory = '/payments/me/history';
  static String paymentHold(String id) => '/payments/hold/$id';
  static String paymentConfirm(String id) => '/payments/confirm/$id';
  static String paymentByBooking(String id) => '/payments/booking/$id';

  // ── Bookings: start with PIN, no-show ────────────────────────────────────
  static String bookingStart(String id) => '/bookings/$id/start';
  static String bookingNoShowCustomer(String id) =>
      '/bookings/$id/no-show/customer';
  static String bookingNoShowWorker(String id) =>
      '/bookings/$id/no-show/worker';

  // ── Disputes ──────────────────────────────────────────────────────────────
  static const String disputes = '/payments/disputes';
  static const String disputesMy = '/payments/disputes/my';
  static const String disputesWorkerMine = '/payments/disputes/worker-mine';
  static String disputeEvidence(String id) => '/payments/disputes/$id/evidence';
  static String disputeAppeal(String id) => '/payments/disputes/$id/appeal';
  static String disputeById(String id) => '/payments/disputes/$id';
  static String disputePartyById(String id) => '/payments/disputes/party/$id';

  // ── Notification preferences ──────────────────────────────────────────────
  static const String notificationPreferences = '/notifications/preferences';

  static const String savedCards = '/saved-cards';
  static String savedCard(String id) => '/saved-cards/$id';
  static String defaultSavedCard(String id) => '/saved-cards/$id/default';

  // ── Booking accept (dedicated endpoint — enforces cash debt gate) ──────────
  static String bookingAccept(String id) => '/bookings/$id/accept';

  // ── File upload (returns { url: String }) ─────────────────────────────────
  static const String uploadFile = '/uploads';

  // ── Support issues ─────────────────────────────────────────────────────────
  static const String supportIssues = '/support/issues';
  static const String supportIssuesMy = '/support/issues/my';
  static String supportIssueStatus(String id) => '/support/issues/$id/status';
  static String supportIssueResolve(String id) => '/support/issues/$id/resolve';
  static String supportIssueEscalate(String id) => '/support/issues/$id/escalate-dispute';
}
