import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/components.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../core/platform/platform_bridge.dart';
import '../../../domain/model/drama_extra_details.dart';

class CuratedStreamingApp {
  final String name;
  final List<String> aliases;
  final String packageName;
  final String Function(String encodedTitle)? appDeepLink;
  final String Function(String encodedTitle) webDeepLink;

  const CuratedStreamingApp({
    required this.name,
    required this.aliases,
    required this.packageName,
    this.appDeepLink,
    required this.webDeepLink,
  });
}

/// Curated streaming platforms with Android package & deep-link support.
final List<CuratedStreamingApp> kCuratedStreamingApps = [
  CuratedStreamingApp(
    name: 'Netflix',
    aliases: const [
      'Netflix',
      'Netflix Standard with Ads',
      'Netflix Basic with Ads',
    ],
    packageName: 'com.netflix.mediaclient',
    appDeepLink: (q) => 'nflx://www.netflix.com/search?q=$q',
    webDeepLink: (q) => 'https://www.netflix.com/search?q=$q',
  ),
  CuratedStreamingApp(
    name: 'Prime Video',
    aliases: const ['Amazon Prime Video', 'Prime Video', 'Amazon Video'],
    packageName: 'com.amazon.avod.thirdpartyclient',
    webDeepLink: (q) =>
        'https://www.primevideo.com/search/ref=atv_nb_sr?phrase=$q',
  ),
  CuratedStreamingApp(
    name: 'Disney+ Hotstar',
    aliases: const ['Disney+ Hotstar', 'JioHotstar', 'Hotstar'],
    packageName: 'in.startv.hotstar',
    webDeepLink: (q) => 'https://www.hotstar.com/in/explore?search_query=$q',
  ),
  CuratedStreamingApp(
    name: 'Disney+',
    aliases: const ['Disney+', 'Disney Plus'],
    packageName: 'com.disney.disneyplus',
    webDeepLink: (q) => 'https://www.disneyplus.com/search?q=$q',
  ),
  CuratedStreamingApp(
    name: 'Max',
    aliases: const ['Max', 'HBO Max'],
    packageName: 'com.wbd.stream',
    webDeepLink: (q) => 'https://play.max.com/search?q=$q',
  ),
  CuratedStreamingApp(
    name: 'Hulu',
    aliases: const ['Hulu'],
    packageName: 'com.hulu.plus',
    webDeepLink: (q) => 'https://www.hulu.com/search?q=$q',
  ),
  CuratedStreamingApp(
    name: 'Apple TV+',
    aliases: const ['Apple TV+', 'Apple TV Plus', 'Apple TV'],
    packageName: 'com.apple.atve.androidtv.appletv',
    webDeepLink: (q) => 'https://tv.apple.com/search?term=$q',
  ),
  CuratedStreamingApp(
    name: 'Crunchyroll',
    aliases: const ['Crunchyroll'],
    packageName: 'com.crunchyroll.crunchyroid',
    webDeepLink: (q) => 'https://www.crunchyroll.com/search?q=$q',
  ),
  CuratedStreamingApp(
    name: 'Rakuten Viki',
    aliases: const ['Rakuten Viki', 'Viki'],
    packageName: 'com.viki.android',
    webDeepLink: (q) => 'https://www.viki.com/search?q=$q',
  ),
  CuratedStreamingApp(
    name: 'iQIYI',
    aliases: const ['iQIYI', 'iQiyi'],
    packageName: 'com.iqiyi.i18n',
    webDeepLink: (q) => 'https://www.iq.com/search?query=$q',
  ),
  CuratedStreamingApp(
    name: 'WeTV',
    aliases: const ['WeTV', 'Tencent Video'],
    packageName: 'com.tencent.qqlivei18n',
    webDeepLink: (q) => 'https://wetv.vip/en/search?q=$q',
  ),
  CuratedStreamingApp(
    name: 'YouTube',
    aliases: const ['YouTube', 'YouTube Premium'],
    packageName: 'com.google.android.youtube',
    webDeepLink: (q) => 'https://www.youtube.com/results?search_query=$q',
  ),
  CuratedStreamingApp(
    name: 'Plex',
    aliases: const ['Plex', 'Plex Channel'],
    packageName: 'com.plexapp.android',
    webDeepLink: (q) => 'https://watch.plex.tv/search?q=$q',
  ),
];

CuratedStreamingApp? findCuratedStreamingApp(String providerName) {
  final normalized = providerName.trim().toLowerCase();
  for (final app in kCuratedStreamingApps) {
    for (final alias in app.aliases) {
      final a = alias.toLowerCase();
      if (normalized == a || normalized.contains(a)) {
        return app;
      }
    }
  }
  return null;
}

(String, String)? resolvePrimaryWatchLinkForShare({
  required int dramaId,
  required String dramaTitle,
  required List<StreamingProvider> watchProviders,
}) {
  if (watchProviders.isEmpty) return null;
  final primary = watchProviders.first;
  final encodedTitle = Uri.encodeComponent(dramaTitle.trim());
  final curated = findCuratedStreamingApp(primary.name);
  final url = curated?.webDeepLink(encodedTitle) ??
      ((primary.link != null &&
              primary.link!.toLowerCase().startsWith('https://'))
          ? primary.link!
          : 'https://www.themoviedb.org/tv/$dramaId/watch');
  return (primary.name, url);
}

class WatchProvidersSection extends StatefulWidget {
  final int dramaId;
  final String dramaTitle;
  final List<StreamingProvider> watchProviders;
  final Color accentColor;

  const WatchProvidersSection({
    super.key,
    required this.dramaId,
    required this.dramaTitle,
    required this.watchProviders,
    required this.accentColor,
  });

  @override
  State<WatchProvidersSection> createState() => _WatchProvidersSectionState();
}

class _WatchProvidersSectionState extends State<WatchProvidersSection> {
  final Map<String, bool> _installedCache = {};

  @override
  void initState() {
    super.initState();
    _detectInstalledApps();
  }

  @override
  void didUpdateWidget(covariant WatchProvidersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watchProviders != widget.watchProviders) {
      _detectInstalledApps();
    }
  }

  Future<void> _detectInstalledApps() async {
    final checks = <String, bool>{};
    for (final provider in widget.watchProviders) {
      final curated = findCuratedStreamingApp(provider.name);
      if (curated != null && !checks.containsKey(curated.packageName)) {
        checks[curated.packageName] =
            await PlatformBridge.isPackageInstalled(curated.packageName);
      }
    }
    if (mounted) {
      setState(() => _installedCache.addAll(checks));
    }
  }

  Future<void> _launchProvider(StreamingProvider provider) async {
    final encoded = Uri.encodeComponent(widget.dramaTitle.trim());
    final curated = findCuratedStreamingApp(provider.name);
    if (curated != null) {
      final installed = _installedCache[curated.packageName] ?? false;
      if (installed && curated.appDeepLink != null) {
        final ok = await PlatformBridge.launchPackageDeepLink(
          curated.packageName,
          curated.appDeepLink!(encoded),
        );
        if (ok) return;
      }
      final webUri = Uri.parse(curated.webDeepLink(encoded));
      if (await launchUrl(webUri, mode: LaunchMode.externalApplication)) return;
    }

    final hubUrl = (provider.link != null &&
            provider.link!.toLowerCase().startsWith('https://'))
        ? provider.link!
        : 'https://www.themoviedb.org/tv/${widget.dramaId}/watch';
    await launchUrl(Uri.parse(hubUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final deviceCountry =
        (ui.PlatformDispatcher.instance.locale.countryCode ?? 'US')
            .toUpperCase();
    final safeCountry = deviceCountry.isEmpty ? 'US' : deviceCountry;
    if (widget.watchProviders.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = List<StreamingProvider>.from(widget.watchProviders)
      ..sort((a, b) {
        final ca = findCuratedStreamingApp(a.name);
        final cb = findCuratedStreamingApp(b.name);
        final ia =
            (ca != null && (_installedCache[ca.packageName] ?? false)) ? 1 : 0;
        final ib =
            (cb != null && (_installedCache[cb.packageName] ?? false)) ? 1 : 0;
        return ib.compareTo(ia);
      });

    final first = sorted.first;
    final activeRegion = (first.regionCode ?? '').trim().isNotEmpty
        ? first.regionCode!
        : safeCountry;
    final isFallback = first.isRegionFallback;
    final regionBadgeText = (isFallback && activeRegion != safeCountry)
        ? 'Not in $safeCountry · Showing $activeRegion'
        : 'Region: $activeRegion';

    final railHeight = 56.0 + ((textScale - 1.0).clamp(0.0, 1.0) * 40.0);

    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Where to Watch',
                style: t.headline.copyWith(color: c.label),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: ShapeDecoration(
                  color: c.tertiaryBackground,
                  shape: MoglogShapes.smooth(7),
                ),
                child: Text(
                  regionBadgeText,
                  style: t.caption2.copyWith(
                    color: isFallback ? c.secondaryLabel : c.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, idx) {
                final provider = sorted[idx];
                final curated = findCuratedStreamingApp(provider.name);
                final isInstalled = curated != null &&
                    (_installedCache[curated.packageName] ?? false);
                final availability =
                    (provider.availabilityType ?? '').trim().isNotEmpty
                        ? provider.availabilityType!
                        : 'Stream';
                final subtitle =
                    isInstalled ? 'Installed · $availability' : availability;

                return IosPressable(
                  semanticLabel: 'Open ${provider.name}, $subtitle',
                  onTap: () => _launchProvider(provider),
                  hapticOnTap: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: ShapeDecoration(
                      color: c.tertiaryBackground,
                      shape: MoglogShapes.smooth(
                        MoglogShapes.controlRadius,
                        side: BorderSide(
                          color: isInstalled
                              ? widget.accentColor.withValues(alpha: 0.45)
                              : c.glassBorder,
                          width: c.hairlineWidth,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (provider.logoUrl != null) ...[
                          PosterImage(
                            url: provider.logoUrl!,
                            width: 32,
                            height: 32,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                          ),
                          const SizedBox(width: 9),
                        ],
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              provider.name,
                              maxLines: 1,
                              style: t.footnote.copyWith(
                                color: c.label,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              style: t.caption2.copyWith(
                                color: isInstalled
                                    ? widget.accentColor
                                    : c.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Availability data powered by JustWatch · Tap any platform to open',
            style: t.caption2.copyWith(color: c.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
