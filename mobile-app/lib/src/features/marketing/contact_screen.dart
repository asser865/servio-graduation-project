import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/contact_api.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = 'Please complete the required fields before sending.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ContactApi(context.read<ApiClient>());
      await api.sendMessage(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _successMessage = 'Message sent. We will reply within 2 hours.';
        _nameController.clear();
        _emailController.clear();
        _subjectController.clear();
        _messageController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to send message. Please try again.';
      });
    }
  }

  Future<void> _launchContact(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || launched) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open ${uri.scheme}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23)),
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: ServioSpacing.screenPadding,
            right: ServioSpacing.screenPadding,
            top: 16,
            bottom: 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Hero Section
              Text(
                'Get in touch',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                ),
              ),
              const SizedBox(height: 5),

              // Form Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF9A8C73).withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(26, 29, 37, 0.04),
                      blurRadius: 24,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9A8C73).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.mail_outline_rounded, color: Color(0xFF9A8C73), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Send a message',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Fill out the form below and we'll reply to your email.",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: servio.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration(
                          label: 'Full Name',
                          hint: 'Mostafa Abdelaal',
                          prefixIcon: Icons.person_outline_rounded,
                          isDark: isDark,
                        ),
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration(
                          label: 'Email Address',
                          hint: 'mostafa@example.com',
                          prefixIcon: Icons.alternate_email_rounded,
                          isDark: isDark,
                        ),
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _subjectController,
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration(
                          label: 'Subject',
                          hint: 'How can we help?',
                          prefixIcon: Icons.subject_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _messageController,
                        minLines: 5,
                        maxLines: 7,
                        textInputAction: TextInputAction.newline,
                        decoration: _buildInputDecoration(
                          label: 'Message',
                          hint: 'Please provide details...',
                          prefixIcon: Icons.chat_bubble_outline_rounded,
                          isDark: isDark,
                        ),
                        validator: _requiredValidator,
                      ),
                      if (_successMessage != null || _errorMessage != null) ...<Widget>[
                        const SizedBox(height: 14),
                        _InlineMessage(
                          message: _successMessage ?? _errorMessage!,
                          color: _successMessage != null ? servio.success : servio.danger,
                          icon: _successMessage != null
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9A8C73),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF9A8C73).withValues(alpha: 0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Send Message',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),

              // Contact Details (Bento-style Cards)
              _BentoContactCard(
                icon: Icons.mail_rounded,
                title: 'Email Us',
                subtitle: 'Drop us a line anytime.',
                value: 'support@servio.com',
                onTap: () => _launchContact(Uri(scheme: 'mailto', path: 'support@servio.com')),
                isDark: isDark,
                servio: servio,
              ),
              const SizedBox(height: 10),
              _BentoContactCard(
                icon: Icons.phone_rounded,
                title: 'Call Us',
                subtitle: 'Everyday from 8am to 12pm.',
                value: '+20 1006665555',
                onTap: () => _launchContact(Uri(scheme: 'tel', path: '+201006665555')),
                isDark: isDark,
                servio: servio,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label.toUpperCase(),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: isDark ? const Color(0xFFE3D5CA).withValues(alpha: 0.7) : const Color(0xFF1A1D23).withValues(alpha: 0.7),
      ),
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF9A8C73)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1A1D23) : const Color(0xFFF5F3F0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: const Color(0xFF9A8C73).withValues(alpha: 0.1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF9A8C73), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  static String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required.';
    return null;
  }

  static String? _emailValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required.';
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class _BentoContactCard extends StatelessWidget {
  const _BentoContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.servio,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool isDark;
  final ServioThemeExtension servio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF9A8C73).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D23) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(26, 29, 37, 0.03),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: servio.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: onTap != null ? const Color(0xFF9A8C73) : (isDark ? Colors.white : const Color(0xFF262B34)),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                color: servio.textSecondary.withValues(alpha: 0.7),
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
