import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_banner.dart';
import '../../providers/local_service_provider.dart';
import '../../models/local_service.dart';

class LocalServicesScreen extends StatefulWidget {
  const LocalServicesScreen({super.key});

  @override
  State<LocalServicesScreen> createState() => _LocalServicesScreenState();
}

class _LocalServicesScreenState extends State<LocalServicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalServiceProvider>().loadServices();
    });
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'guide':
        return Icons.person;
      case 'artisan':
        return Icons.handyman;
      case 'accommodation':
        return Icons.hotel;
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'equipment':
        return Icons.backpack;
      default:
        return Icons.store;
    }
  }

  String _getCategoryText(String category) {
    switch (category) {
      case 'guide':
        return 'Guide';
      case 'artisan':
        return 'Artisan';
      case 'accommodation':
        return 'Hebergement';
      case 'restaurant':
        return 'Restaurant';
      case 'transport':
        return 'Transport';
      case 'equipment':
        return 'Equipement';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalServiceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Annuaire Local'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              provider.setCategoryFilter(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Tous'),
              ),
              ...AppConstants.serviceCategories.map((c) => PopupMenuItem(
                value: c,
                child: Row(
                  children: [
                    Icon(_getCategoryIcon(c), size: 20),
                    const SizedBox(width: 8),
                    Text(_getCategoryText(c)),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.error != null && provider.error!.isNotEmpty)
            ErrorBanner(
              message: provider.error!,
              onRetry: provider.loadServices,
              onDismiss: provider.clearError,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await provider.loadServices();
              },
              child: provider.isLoading && provider.services.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.services.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Aucun service trouve'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.services.length,
                          itemBuilder: (context, index) {
                            final service = provider.services[index];
                            return _ServiceCard(service: service);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final LocalService service;

  const _ServiceCard({required this.service});

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'guide':
        return Icons.person;
      case 'artisan':
        return Icons.handyman;
      case 'accommodation':
        return Icons.hotel;
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'equipment':
        return Icons.backpack;
      default:
        return Icons.store;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image or placeholder
          if (service.imageUrl != null)
            CachedNetworkImage(
              imageUrl: service.imageUrl!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 150,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 150,
                color: Colors.grey[200],
                child: Icon(_getCategoryIcon(service.category), size: 48),
              ),
            )
          else
            Container(
              height: 100,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Center(
                child: Icon(
                  _getCategoryIcon(service.category),
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and verified badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (service.isVerified)
                      const Icon(Icons.verified, color: Colors.blue, size: 20),
                  ],
                ),
                const SizedBox(height: 4),

                // Category
                Row(
                  children: [
                    Icon(
                      _getCategoryIcon(service.category),
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service.categoryDisplayName,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Rating
                if (service.rating != null)
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < service.rating!.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 18,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        '${service.rating!.toStringAsFixed(1)} (${service.reviewCount})',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),

                // Description
                Text(
                  service.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),

                // Languages
                if (service.languages != null && service.languages!.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: service.languages!.map((lang) {
                      return Chip(
                        label: Text(lang, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    if (service.contact != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchPhone(service.contact!),
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('Appeler'),
                        ),
                      ),
                    if (service.contact != null && service.email != null)
                      const SizedBox(width: 8),
                    if (service.email != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchEmail(service.email!),
                          icon: const Icon(Icons.email, size: 18),
                          label: const Text('Email'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
