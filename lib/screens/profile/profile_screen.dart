import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/providers/auth_provider.dart';
import 'package:aadya_plus/models/user.dart';
import 'package:aadya_plus/utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Premium gradient colors
  static const _gradientStart = Color(0xFF0284C7); // Sky 600
  static const _gradientMid = Color(0xFF0EA5E9); // Sky 500
  static const _gradientEnd = Color(0xFF38BDF8); // Sky 400
  static const _accentTeal = Color(0xFF14B8A6); // Teal 500
  static const _surfaceColor = Color(0xFFF8FAFC);
  static const _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      _showErrorSnackBar('Please fill all required fields');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user!;

    final updatedUser = User(
      id: currentUser.id,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      profileImage: currentUser.profileImage,
      createdAt: currentUser.createdAt,
    );

    try {
      await authProvider.updateProfile(updatedUser);
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        _showSuccessSnackBar('Profile updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update profile: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEE2E2), Color(0xFFFECACA)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.logout_rounded,
                    size: 36, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to logout?',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        await authProvider.logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: _gradientStart))
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
              
                slivers: [
                  // ─── Gradient Header with Avatar ───
                  SliverToBoxAdapter(
                    child: _buildGradientHeader(user, screenWidth),
                  ),

                  // ─── Profile Completion & Stats (Animated) ───
                  SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _isEditing 
                        ? const SizedBox.shrink() 
                        : Column(
                            key: const ValueKey('stats_and_completion'),
                            children: [
                              _buildProfileCompletion(),
                              _buildQuickStats(),
                            ],
                          ),
                    ),
                  ),

                  // ─── Main Content (Edit Form or Menu) ───
                  SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.05),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: _isEditing
                          ? _buildEditForm(key: const ValueKey('edit_form'))
                          : _buildProfileContent(key: const ValueKey('profile_content')),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Profile Content Holder ──────────────────────────────────
  Widget _buildProfileContent({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staggered animated sections
          _buildAnimatedSection(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel('Health'),
                _buildMenuCard([
                  _MenuItemData(
                    icon: Icons.medical_services_rounded,
                    title: 'My Doctors',
                    subtitle: 'View saved doctors',
                    gradientColors: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                    onTap: () {},
                  ),
                  _MenuItemData(
                    icon: Icons.local_hospital_rounded,
                    title: 'Saved Hospitals',
                    subtitle: 'Nearby hospitals',
                    gradientColors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                    onTap: () {},
                  ),
                  _MenuItemData(
                    icon: Icons.description_rounded,
                    title: 'Medical Records',
                    subtitle: 'Reports & prescriptions',
                    gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                    onTap: () {},
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildAnimatedSection(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel('Account'),
                _buildMenuCard([
                  _MenuItemData(
                    icon: Icons.payment_rounded,
                    title: 'Payment Methods',
                    subtitle: 'Cards & UPI',
                    gradientColors: const [Color(0xFFEA580C), Color(0xFFF97316)],
                    onTap: () {},
                  ),
                  _MenuItemData(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    subtitle: 'Manage alerts',
                    gradientColors: const [Color(0xFFDB2777), Color(0xFFEC4899)],
                    onTap: () {},
                  ),
                  _MenuItemData(
                    icon: Icons.shield_rounded,
                    title: 'Privacy & Security',
                    subtitle: 'Data & password',
                    gradientColors: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    onTap: () {},
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildAnimatedSection(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel('Support'),
                _buildMenuCard([
                  _MenuItemData(
                    icon: Icons.headset_mic_rounded,
                    title: 'Help & Support',
                    subtitle: '24/7 assistance',
                    gradientColors: const [Color(0xFF0891B2), Color(0xFF06B6D4)],
                    onTap: () {},
                  ),
                  _MenuItemData(
                    icon: Icons.info_rounded,
                    title: 'About App',
                    subtitle: 'Version & info',
                    gradientColors: const [Color(0xFF64748B), Color(0xFF94A3B8)],
                    onTap: () {},
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          _buildAnimatedSection(
            index: 3,
            child: Column(
              children: [
                _buildActionButton(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: Icons.edit_rounded,
                  label: 'Edit Profile',
                  isPrimary: true,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  onPressed: _logout,
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  isPrimary: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildAppVersion(),
        ],
      ),
    );
  }

  Widget _buildAnimatedSection({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    if (isPrimary) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_gradientStart, _gradientEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _gradientStart.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: Colors.white),
          label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: const Color(0xFFDC2626)),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
          backgroundColor: const Color(0xFFFEF2F2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Aadya Plus v1.0.0',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }


  // ─── Gradient Header ─────────────────────────────────────────────
  Widget _buildGradientHeader(User user, double screenWidth) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_gradientStart, _gradientMid, _gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  const Text(
                    'My Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings_rounded,
                        color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Avatar
            Hero(
              tag: 'user_profile_avatar',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Potential: Show full image preview
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: user.profileImage != null
                            ? CircleAvatar(
                                radius: 38,
                                backgroundImage: NetworkImage(user.profileImage!),
                              )
                            : Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: child,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF34D399)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Name & Email
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email_rounded,
                    size: 12, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_rounded,
                    size: 12, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  user.phone,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),

            // Curved bottom edge
            const SizedBox(height: 24),
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick Stats ─────────────────────────────────────────────────
  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              '12',
              'Appointments',
              Icons.calendar_month_rounded,
              const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
            ),
            Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
            _buildStatItem(
              '5',
              'Doctors',
              Icons.medical_services_rounded,
              const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
            ),
            Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
            _buildStatItem(
              '8',
              'Orders',
              Icons.shopping_bag_rounded,
              const [Color(0xFFEA580C), Color(0xFFF97316)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String count, String label, IconData icon, List<Color> colors) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 6),
        Text(
          count,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── Profile Completion Indicator ────────────────────────────────
  Widget _buildProfileCompletion() {
    // Mock completion logic
    double completion = 0.85; 
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Profile Completion',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(completion * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _gradientStart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: completion,
                backgroundColor: _gradientStart.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(_gradientStart),
                minHeight: 5,
              ),
            ),
            if (completion < 1.0) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _isEditing = true),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Complete your profile for better experience',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Edit Form ───────────────────────────────────────────────────
  Widget _buildEditForm({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: _gradientStart, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Personal Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGradientTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_rounded,
                  hint: 'Enter your full name',
                ),
                const SizedBox(height: 16),
                _buildGradientTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  hint: 'yourname@example.com',
                ),
                const SizedBox(height: 16),
                _buildGradientTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_iphone_rounded,
                  keyboardType: TextInputType.phone,
                  hint: '+91 00000 00000',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _loadUserData();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Discard',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_gradientStart, _accentTeal]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _gradientStart.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400, fontSize: 13),
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _gradientStart.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _gradientStart, size: 18),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _gradientStart, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
      ],
    );
  }

  // ─── Section Label ───────────────────────────────────────────────
  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ─── Menu Card ───────────────────────────────────────────────────
  Widget _buildMenuCard(List<_MenuItemData> items) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: index == 0
                        ? const Radius.circular(18)
                        : Radius.zero,
                    bottom:
                        isLast ? const Radius.circular(18) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient:
                                LinearGradient(colors: item.gradientColors),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: item.gradientColors.first
                                    .withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child:
                              Icon(item.icon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                item.subtitle,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFCBD5E1),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 60),
                  child: Divider(
                    height: 1,
                    color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Helper Data Class ───────────────────────────────────────────────
class _MenuItemData {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });
}
