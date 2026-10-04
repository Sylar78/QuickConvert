"""Génère toutes les icônes de QuickConvert à partir d'un seul dessin.

    pip install cairosvg pillow
    python3 tool/generate_icons.py        (depuis app/)

Le dessin vit ici, en SVG, plutôt que dans un fichier d'image : chaque
plateforme veut le même motif à un cadrage différent (pleine page sur iOS,
zone de sécurité réduite pour l'icône adaptative d'Android, marge pour les
icônes « maskable » du web), et seul un dessin vectoriel se recadre sans perte.
Le texte « PDF » utilise la police Inter du dépôt : elle doit être installée
(`~/.fonts/Inter-Bold.ttf`, puis `fc-cache -f`).
"""

import io
import json
import os

import cairosvg
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)

BACKGROUND = '#F6F7FB'
OUTLINE = '#C5C9D2'
SHADOW = '#FFE3E3'
PAPER = '#FFFFFF'
RED = '#E5252A'
ORANGE = '#E8893A'
BLUE = '#1F6FE0'
GREEN = '#2FA84F'
ARROW = '#5A4FE0'  # violet de la marque, voir core/app_palette.dart


def doc(x, y, w, h, fold, r=34):
    """Une feuille aux coins arrondis, coin supérieur droit plié."""
    return (
        f'M{x + r},{y} H{x + w - fold} L{x + w},{y + fold} V{y + h - r} '
        f'Q{x + w},{y + h} {x + w - r},{y + h} H{x + r} '
        f'Q{x},{y + h} {x},{y + h - r} V{y + r} Q{x},{y} {x + r},{y} Z'
    )


def artwork():
    """Le motif, dans un carré de 1024, contenu entre 112 et 912 environ."""
    # Document source, à gauche, légèrement incliné : les trois formats
    # d'entrée en pastilles de couleur (image, texte, tableau).
    sx, sy, sw, sh = 128, 286, 330, 430
    src = doc(sx, sy, sw, sh, 86)
    # Document PDF, à droite, plus grand.
    px, py, pw, ph = 500, 126, 400, 520
    pdf = doc(px, py, pw, ph, 104, r=40)
    gx = sx + 62  # marge intérieure des pastilles
    return f'''
  <g transform="rotate(-7 {sx + sw / 2} {sy + sh / 2})">
    <path d="{src}" fill="{SHADOW}" transform="translate(-26 30)"/>
    <path d="{src}" fill="{PAPER}" stroke="{OUTLINE}" stroke-width="22" stroke-linejoin="round"/>
    <!-- image -->
    <rect x="{gx}" y="{sy + 66}" width="150" height="104" rx="14" fill="{ORANGE}"/>
    <path d="M{gx + 14},{sy + 156} l42,-46 32,32 22,-20 40,34 z" fill="#FFFFFF" opacity=".75"/>
    <circle cx="{gx + 118}" cy="{sy + 96}" r="13" fill="#FFFFFF" opacity=".85"/>
    <!-- texte -->
    <rect x="{gx}" y="{sy + 204}" width="206" height="24" rx="12" fill="{BLUE}"/>
    <rect x="{gx}" y="{sy + 246}" width="150" height="24" rx="12" fill="{BLUE}"/>
    <!-- tableau -->
    <rect x="{gx}" y="{sy + 302}" width="206" height="84" rx="12" fill="{GREEN}"/>
    <path d="M{gx},{sy + 330} h206 M{gx},{sy + 358} h206 M{gx + 70},{sy + 302} v84 M{gx + 138},{sy + 302} v84"
          stroke="#FFFFFF" stroke-width="8" opacity=".85"/>
  </g>
  <path d="{pdf}" fill="{SHADOW}" transform="translate(-34 38)"/>
  <path d="{pdf}" fill="{PAPER}" stroke="{OUTLINE}" stroke-width="24" stroke-linejoin="round"/>
  <text x="{px + pw / 2}" y="{py + ph / 2 + 58}" text-anchor="middle"
        font-family="Inter" font-weight="700" font-size="164" letter-spacing="-4"
        fill="{RED}">PDF</text>
  <rect x="{px + 92}" y="{py + ph / 2 + 104}" width="{pw - 184}" height="22" rx="11" fill="{RED}" opacity=".35"/>
  <!-- flèches d'échange -->
  <g stroke="{ARROW}" stroke-width="34" stroke-linecap="round" stroke-linejoin="round" fill="none">
    <path d="M372,792 H652 M600,742 L652,792 L600,842"/>
    <path d="M652,890 H372 M424,840 L372,890 L424,940"/>
  </g>
  <!-- étincelles -->
  <g stroke-linecap="round" stroke-width="18">
    <path d="M190,150 v76 M152,188 h76" stroke="#4FC9C2"/>
    <path d="M292,104 v40 M272,124 h40" stroke="#9BCF6B"/>
  </g>
'''


def svg(scale=1.0, background=True):
    """Le motif recadré : [scale] < 1 le rétrécit autour du centre."""
    offset = 512 * (1 - scale)
    bg = f'<rect width="1024" height="1024" fill="{BACKGROUND}"/>' if background else ''
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
        f'{bg}<g transform="translate({offset} {offset}) scale({scale})">{artwork()}</g></svg>'
    )


def render(source, size, opaque):
    png = cairosvg.svg2png(bytestring=source.encode(), output_width=size, output_height=size)
    img = Image.open(io.BytesIO(png))
    # L'App Store refuse une icône avec un canal alpha, même entièrement opaque.
    return img.convert('RGB') if opaque else img.convert('RGBA')


def save(img, *path):
    full = os.path.join(APP, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full, optimize=True)


def main():
    full = svg()
    with open(os.path.join(HERE, 'app_icon.svg'), 'w') as f:
        f.write(full)

    # iOS : pleine page, opaque. Apple arrondit lui-même les coins.
    appicon = os.path.join(APP, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    with open(os.path.join(appicon, 'Contents.json')) as f:
        contents = json.load(f)
    for image in contents['images']:
        points = float(image['size'].split('x')[0])
        factor = int(image['scale'].rstrip('x'))
        save(render(full, round(points * factor), opaque=True),
             appicon, image['filename'])

    # Android, icône classique (avant Android 8) : le motif pleine page dans
    # un carré aux coins arrondis.
    for folder, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        img = render(full, size, opaque=False)
        mask = Image.new('L', (size * 4, size * 4), 0)
        from PIL import ImageDraw
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, size * 4 - 1, size * 4 - 1), radius=size * 4 * 0.18, fill=255)
        img.putalpha(mask.resize((size, size), Image.LANCZOS))
        save(img, 'android', 'app', 'src', 'main', 'res', f'mipmap-{folder}', 'ic_launcher.png')

        # Icône adaptative (Android 8+) : avant-plan de 108 dp dont seuls les
        # 66 dp du centre sont garantis visibles, d'où le motif réduit.
        fg = render(svg(scale=0.68, background=False), size * 108 // 48, opaque=False)
        save(fg, 'android', 'app', 'src', 'main', 'res', f'mipmap-{folder}', 'ic_launcher_foreground.png')

    # Web : favicon, icônes PWA, et variantes « maskable » avec marge de sécurité.
    save(render(full, 32, opaque=False), 'web', 'favicon.png')
    for size in (192, 512):
        save(render(full, size, opaque=False), 'web', 'icons', f'Icon-{size}.png')
        save(render(svg(scale=0.8), size, opaque=False), 'web', 'icons', f'Icon-maskable-{size}.png')
    save(render(full, 180, opaque=True), 'web', 'icons', 'apple-touch-icon.png')


if __name__ == '__main__':
    main()
