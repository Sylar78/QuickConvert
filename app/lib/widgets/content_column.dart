import 'package:flutter/material.dart';
import '../core/core.dart';

/// Centre le contenu et lui donne une largeur maximale.
///
/// C'est ce qui manquait pour le web : sans contrainte, la grille et les
/// cartes s'étiraient sur toute la largeur de l'écran et l'app ressemblait à
/// une maquette agrandie. Sur téléphone, la contrainte ne change rien.
class ContentColumn extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentColumn({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.content,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
