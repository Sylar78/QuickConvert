import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List> renderSvgToPng(String svgString, int width, int height) async {
  final completer = Completer<Uint8List>();

  // Create SVG blob and object URL
  final blob = html.Blob([svgString], 'image/svg+xml');
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Create an Image element to load the SVG
  final img = html.ImageElement();

  img.onLoad.listen((_) {
    // Draw the image on a canvas at desired dimensions
    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;

    // White background
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, width, height);

    // Draw SVG image scaled to fit
    ctx.drawImageScaled(img, 0, 0, width, height);

    // Export as PNG
    final dataUrl = canvas.toDataUrl('image/png');
    final base64Data = dataUrl.split(',')[1];
    final bytes = base64Decode(base64Data);

    html.Url.revokeObjectUrl(url);
    completer.complete(Uint8List.fromList(bytes));
  });

  img.onError.listen((_) {
    html.Url.revokeObjectUrl(url);
    completer.completeError(Exception('Impossible de charger le SVG'));
  });

  // Set dimensions on the img element for proper sizing
  img.width = width;
  img.height = height;
  img.src = url;

  return completer.future;
}
