/// Les formats de fichier que QuickConvert sait lire ou produire.
///
/// L'ordre n'a pas d'importance : rien n'est persisté à partir de cet enum.
/// C'est [ConversionType] qui sert de clé d'historique, et son ordre est figé.
enum FileFormat { pdf, jpg, png, doc, svg }

extension FileFormatX on FileFormat {
  /// Libellé court affiché dans l'interface (« PDF », « JPG »…).
  String get label => switch (this) {
        FileFormat.pdf => 'PDF',
        FileFormat.jpg => 'JPG',
        FileFormat.png => 'PNG',
        FileFormat.doc => 'DOC',
        FileFormat.svg => 'SVG',
      };

  /// Extensions acceptées, en minuscules et sans point.
  List<String> get extensions => switch (this) {
        FileFormat.pdf => const ['pdf'],
        FileFormat.jpg => const ['jpg', 'jpeg'],
        FileFormat.png => const ['png'],
        FileFormat.doc => const ['doc', 'docx'],
        FileFormat.svg => const ['svg'],
      };

  /// Extension utilisée pour nommer un fichier produit dans ce format.
  String get outputExtension => extensions.first;
}
