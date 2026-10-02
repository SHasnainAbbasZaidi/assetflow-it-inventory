import 'package:flutter/material.dart';

/// Compact brand lockup shared by Login and Settings.
class BrandCredit extends StatelessWidget {
  const BrandCredit({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 112,
          height: 58,
          child: Stack(alignment: Alignment.topCenter, children: [
            Image.asset('assets/images/hasnain-zaidi.png',
                width: 82, fit: BoxFit.contain, semanticLabel: 'Hasnain Zaidi'),
            Positioned(
              top: 20,
              child: Image.asset('assets/images/mahzaidex-tech.png',
                  width: 112, fit: BoxFit.contain, semanticLabel: 'Mahzaidex Tech'),
            ),
          ]),
        ),
      );
}
