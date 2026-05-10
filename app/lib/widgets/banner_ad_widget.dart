import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatelessWidget {
  final BannerAd? ad;

  const BannerAdWidget({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    if (ad == null) return const SizedBox.shrink();

    return Container(
      width: ad!.size.width.toDouble(),
      height: ad!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: ad!),
    );
  }
}
