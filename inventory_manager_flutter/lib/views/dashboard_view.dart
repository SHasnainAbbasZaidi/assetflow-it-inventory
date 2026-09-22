import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'dart:convert';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final assets = provider.assets;

    final int total = assets.where((a) => a.status != 'Retired').length;
    final int available = assets.where((a) => a.status == 'In Store').length;
    final int inUse = assets.where((a) => a.status == 'Assigned').length;
    final int retired = assets.where((a) => a.status == 'Retired').length;

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 600 ? 2 : 1);

    Widget logoWidget;
    if (provider.companyLogo.isNotEmpty) {
      try {
        final cleanStr = provider.companyLogo.contains(',') 
            ? provider.companyLogo.split(',')[1] 
            : provider.companyLogo;
        logoWidget = Image.memory(base64Decode(cleanStr), width: 48, height: 48, fit: BoxFit.contain);
      } catch (e) {
        logoWidget = Image.asset('assets/images/default_logo.png', width: 48, height: 48, fit: BoxFit.contain);
      }
    } else {
      logoWidget = Image.asset('assets/images/default_logo.png', width: 48, height: 48, fit: BoxFit.contain);
    }

    final companyName = provider.companyName.isNotEmpty ? provider.companyName : 'AssetFlow Premium';
    final companyAddress = provider.companyAddress;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: logoWidget,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                        ),
                        if (companyAddress.isNotEmpty)
                          Text(
                            companyAddress,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          Text(
                            'IT Inventory Management',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back. Here\'s your inventory status.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 32),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: screenWidth > 600 ? 1.6 : 2.2,
              children: [
                _buildStatCard(
                  context,
                  title: 'Active Assets',
                  value: total.toString(),
                  icon: Icons.devices_rounded,
                  iconColor: const Color(0xFF6366F1),
                  bgColor: const Color(0xFF6366F1).withOpacity(0.12),
                ),
                _buildStatCard(
                  context,
                  title: 'In Store',
                  value: available.toString(),
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFF10B981).withOpacity(0.12),
                ),
                _buildStatCard(
                  context,
                  title: 'Assigned',
                  value: inUse.toString(),
                  icon: Icons.person_outline_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFF3B82F6).withOpacity(0.12),
                ),
                _buildStatCard(
                  context,
                  title: 'Deprecated',
                  value: retired.toString(),
                  icon: Icons.delete_outline_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  bgColor: const Color(0xFFF43F5E).withOpacity(0.12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
