package fr.quickconvert.app

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Le paquet doit être celui du `namespace` de build.gradle : le manifeste
// déclare `.MainActivity`, résolu en `fr.quickconvert.app.MainActivity`.
// L'activité vivait auparavant dans `com.quickconvert.app`, une classe que le
// système n'aurait pas trouvée au lancement.
//
// Elle reçoit aussi les fichiers partagés depuis d'autres apps (voir les
// filtres d'intention du manifeste) : ils sont copiés dans le cache, puis
// remis au code Dart par le canal `fr.quickconvert.app/partage`
// (lib/services/shared_files_service.dart).
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: List<Uri> = emptyList()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = sharedUris(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method != "takeSharedFiles") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uris = pending
                pending = emptyList()
                // Copier peut prendre du temps (jusqu'à 50 Mo) : hors du fil
                // principal, pour ne pas figer l'interface.
                Thread {
                    val files = copyToCache(uris)
                    runOnUiThread { result.success(files) }
                }.start()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uris = sharedUris(intent)
        if (uris.isEmpty()) return
        pending = uris
        channel?.invokeMethod("sharedFilesAvailable", null)
    }

    @Suppress("DEPRECATION")
    private fun sharedUris(intent: Intent?): List<Uri> {
        if (intent == null) return emptyList()
        return when (intent.action) {
            Intent.ACTION_SEND ->
                listOfNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.filterNotNull()
                    ?: emptyList()
            // Les liens `quickconvert://` passent aussi par VIEW : seuls les
            // fichiers nous intéressent ici.
            Intent.ACTION_VIEW ->
                listOfNotNull(intent.data?.takeIf { it.scheme == "content" || it.scheme == "file" })
            else -> emptyList()
        }
    }

    private fun copyToCache(uris: List<Uri>): List<Map<String, Any>> {
        if (uris.isEmpty()) return emptyList()
        // Un seul lot à la fois : le précédent est remplacé, comme une
        // nouvelle sélection dans l'app.
        val dir = File(cacheDir, "partages")
        dir.deleteRecursively()
        dir.mkdirs()

        val files = mutableListOf<Map<String, Any>>()
        for ((index, uri) in uris.withIndex()) {
            try {
                val name = displayName(uri, index)
                val target = uniqueFile(dir, name)
                val input = contentResolver.openInputStream(uri) ?: continue
                input.use { source -> target.outputStream().use { source.copyTo(it) } }
                files.add(mapOf("path" to target.absolutePath, "name" to target.name, "size" to target.length()))
            } catch (e: Exception) {
                // Un fichier illisible n'empêche pas les autres d'arriver.
            }
        }
        return files
    }

    /// Le nom d'origine, avec une extension : c'est elle qui permet à l'app
    /// de reconnaître le format. Certaines apps n'en fournissent pas, on la
    /// déduit alors du type MIME.
    private fun displayName(uri: Uri, index: Int): String {
        var name: String? = null
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) name = cursor.getString(0)
            }
        } catch (e: Exception) {
            // Fournisseur sans colonne de nom : on retombe sur le chemin.
        }
        if (name.isNullOrBlank()) name = uri.lastPathSegment?.substringAfterLast('/')
        var base = name?.replace('/', '_')?.takeIf { it.isNotBlank() } ?: "fichier_${index + 1}"
        if (!base.contains('.')) {
            val ext = contentResolver.getType(uri)?.let {
                MimeTypeMap.getSingleton().getExtensionFromMimeType(it)
            }
            if (ext != null) base = "$base.$ext"
        }
        return base
    }

    private fun uniqueFile(dir: File, name: String): File {
        var file = File(dir, name)
        var n = 2
        while (file.exists()) {
            val dot = name.lastIndexOf('.')
            file = if (dot > 0) File(dir, "${name.substring(0, dot)}_$n${name.substring(dot)}")
            else File(dir, "${name}_$n")
            n++
        }
        return file
    }

    companion object {
        private const val CHANNEL = "fr.quickconvert.app/partage"
    }
}
