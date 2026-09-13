import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:aadya_plus/utils/constants.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // Using Iconsax for a smooth professional look. Same icon for outline/filled to keep it simple and compile-safe.
  final List<NavBarItemData> _navItems = [
    NavBarItemData("Home", Iconsax.home, Iconsax.home),
    NavBarItemData("Doctors", Iconsax.health, Iconsax.health),
    NavBarItemData("Pharmacy", Iconsax.shop, Iconsax.shop),
    NavBarItemData("Appointments", Iconsax.calendar, Iconsax.calendar),
    NavBarItemData("Profile", Iconsax.user, Iconsax.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final isSelected = currentIndex == index;
              return Material(
                color: Colors.transparent,
                child: InkResponse(
                  onTap: () => onTap(index),
                  radius: 36, // Defines the ripple spread
                  splashColor: AppConstants.primaryColor.withOpacity(0.12),
                  highlightColor: AppConstants.primaryColor.withOpacity(0.05),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            isSelected ? _navItems[index].activeIcon : _navItems[index].icon,
                            size: 24,
                            color: isSelected ? AppConstants.primaryColor : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppConstants.primaryColor : Colors.grey.shade500,
                          ),
                          child: Text(_navItems[index].label),
                        ),
                        // Clean dot indicator
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: 3,
                          width: isSelected ? 4 : 0,
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class NavBarItemData {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  NavBarItemData(this.label, this.icon, this.activeIcon);
}