#!/usr/bin/env python3
"""Generate repository-owned SVG artwork. No third-party packages are needed."""
from pathlib import Path
from html import escape
import textwrap

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "images"
OUT.mkdir(parents=True, exist_ok=True)

hero = '''<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="520" viewBox="0 0 1440 520" role="img" aria-labelledby="title desc">
<title id="title">InkReader · 墨卷</title><desc id="desc">A native iOS reader for AI-generated Markdown novels. An evergreen and warm paper banner with an open book illustration.</desc>
<defs><linearGradient id="bg" x2="1" y2="1"><stop stop-color="#2A493B"/><stop offset="1" stop-color="#172E25"/></linearGradient><linearGradient id="paper" x2="1" y2="1"><stop stop-color="#F3EBD5"/><stop offset="1" stop-color="#D8CDAC"/></linearGradient></defs>
<rect width="1440" height="520" rx="28" fill="url(#bg)"/>
<circle cx="1280" cy="420" r="340" fill="#FFF" opacity=".025"/><circle cx="1260" cy="430" r="270" fill="none" stroke="#DAC79A" opacity=".13"/>
<path d="M1020 465C1250 365 1175 80 1390 40M1120 390C1070 280 1090 260 1110 218M1210 270C1300 280 1330 200 1350 160" fill="none" stroke="#D8DCCB" stroke-width="2" opacity=".12"/>
<g font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
<text x="80" y="65" font-size="13" letter-spacing="4" fill="#C4D0BF">NATIVE iOS NOVEL READER</text>
<text x="76" y="177" font-size="88" font-weight="600" letter-spacing="-3" fill="#FBF8EF">InkReader</text>
<text x="84" y="229" font-family="'Songti SC','Noto Serif CJK SC',serif" font-size="32" letter-spacing="12" fill="#DAC79A">墨卷</text>
<text x="80" y="302" font-size="30" font-weight="400" fill="#FBF8EF">A quiet home for your next chapter.</text>
<text x="80" y="342" font-size="20" fill="#C4D0BF">Read AI-generated Markdown novels on your iPhone.</text>
<g font-size="12" letter-spacing="1.4" fill="#EAE4D1">
<rect x="80" y="389" width="172" height="42" rx="21" fill="#FFFFFF" opacity=".07"/><text x="109" y="415">OFFLINE LIBRARY</text>
<rect x="268" y="389" width="170" height="42" rx="21" fill="#FFFFFF" opacity=".07"/><text x="302" y="415">MD + TXT</text>
<rect x="454" y="389" width="180" height="42" rx="21" fill="#FFFFFF" opacity=".07"/><text x="482" y="415">MADE WITH SWIFTUI</text>
</g>
<text x="80" y="476" font-size="11" letter-spacing="2" fill="#AEBEAC">YOUR BOOKS. YOUR PACE. YOUR IPHONE.</text>
</g>
<g transform="translate(1000 110)">
<rect x="-20" y="-20" width="300" height="300" rx="62" fill="#14281F" stroke="#68806C" stroke-opacity=".5"/>
<path d="M28 66Q86 48 124 83V235Q76 206 28 218Z" fill="url(#paper)"/>
<path d="M136 83Q180 49 232 66V218Q183 207 136 235Z" fill="url(#paper)"/>
<path d="M51 110Q81 103 103 116M51 135Q81 128 103 141M51 160Q81 153 103 166" fill="none" stroke="#B2A174" stroke-width="3" stroke-linecap="round"/>
<path d="M188 62L208 63V139L198 130L188 139Z" fill="#BCA468"/>
<path d="M32 236Q81 225 124 250M136 250Q185 225 230 236" fill="none" stroke="#DAC79A" stroke-width="2" opacity=".6"/>
</g></svg>'''
(OUT / "hero.svg").write_text(hero, encoding="utf-8")

novel = (ROOT / "InkReader/Resources/诛仙同人·长相守.md").read_text(encoding="utf-8")
paragraphs = novel.split("## 第01章 铃声未歇", 1)[1].strip().split("\n\n")[:3]
themes = [("WARM PAPER", "F6F0E5", "343A34"), ("CLEAN WHITE", "FAFAF8", "292E2B"), ("NIGHT READING", "181C1B", "C6CEC7")]
parts = ['''<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="900" viewBox="0 0 1440 900" role="img" aria-labelledby="title desc">
<title id="title">Three ways to settle into a story</title><desc id="desc">Illustrations of the app's warm paper, clean white, and night reading palettes, with Chinese sample text. These are layout illustrations, not device screenshots.</desc>
<rect width="1440" height="900" rx="24" fill="#F1F0EB"/>
<g font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" fill="#243D32"><text x="48" y="49" font-size="12" letter-spacing="3">READING THEMES · UI ILLUSTRATIONS</text><text x="48" y="91" font-size="28" font-weight="500">Three ways to settle into a story.</text></g>''']
for i, (label, bg, fg) in enumerate(themes):
    x = 48 + i * 456
    parts.append(f'''<g transform="translate({x} 128)">
    <rect width="432" height="680" rx="22" fill="#{bg}" stroke="#D4D8CD"/>
    <g fill="#{fg}"><text x="30" y="38" font-family="sans-serif" font-size="11" letter-spacing="2" opacity=".65">{label}</text>
    <line x1="28" y1="58" x2="404" y2="58" stroke="#{fg}" opacity=".12"/>
    <text x="30" y="93" font-family="sans-serif" font-size="12" opacity=".6">诛仙同人 · 长相守</text>
    <text x="30" y="143" font-family="'Songti SC','Noto Serif CJK SC',serif" font-size="25" font-weight="600">第01章 铃声未歇</text>''')
    y = 194
    for paragraph in paragraphs:
        lines = textwrap.wrap("　　" + paragraph.replace("\n", ""), width=19, drop_whitespace=False)
        for line in lines:
            parts.append(f'<text x="30" y="{y}" font-family="\'Songti SC\',\'Noto Serif CJK SC\',serif" font-size="19">{escape(line)}</text>')
            y += 36
        y += 17
    parts.append(f'''<line x1="28" y1="615" x2="404" y2="615" stroke="#{fg}" opacity=".12"/>
    <text x="30" y="648" font-family="sans-serif" font-size="11" opacity=".55">目录</text><text x="182" y="648" font-family="monospace" font-size="11" opacity=".45">01 / 50</text><text x="376" y="648" font-family="sans-serif" font-size="11" opacity=".55">排版</text></g>
    <text x="8" y="717" font-family="monospace" font-size="12" fill="#778178">BACKGROUND #{bg} / TEXT #{fg}</text></g>''')
parts.append('</svg>')
(OUT / "themes.svg").write_text("\n".join(parts), encoding="utf-8")

flow = ['''<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="350" viewBox="0 0 1440 350" role="img" aria-labelledby="title desc">
<title id="title">From Markdown to your next chapter</title><desc id="desc">Import a Markdown or text file, detect chapters, read the book, and restore the saved position. All steps run locally on the iPhone.</desc>
<defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="7" refY="4" orient="auto"><path d="M1 1L7 4L1 7" fill="none" stroke="#7B897B" stroke-width="1.5"/></marker></defs>
<rect width="1440" height="350" rx="24" fill="#F4F4EF"/>
<g font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif"><text x="48" y="49" font-size="12" letter-spacing="3" fill="#778178">FROM FILE TO STORY</text>''']
steps = [("01", "Import your novel", ".md / .markdown / .txt", "Files picker or Open In"), ("02", "Find the chapters", "Chinese + English headings", "Skip the generated contents"), ("03", "Make yourself at home", "Themes, type and bookmarks", "Read one chapter at a time"), ("04", "Pick up where you left off", "Per-book saved position", "Ready when you return")]
for i, (number, title, a, b) in enumerate(steps):
    x = 48 + i * 348
    flow.append(f'''<g transform="translate({x} 86)"><rect width="300" height="174" rx="18" fill="#FFFFFF" stroke="#DDE2D7"/><text x="22" y="37" font-family="monospace" font-size="13" fill="#9B8B5D">{number}</text><text x="22" y="73" font-size="18" font-weight="600" fill="#243D32">{escape(title)}</text><text x="22" y="110" font-size="14" fill="#778178">{escape(a)}</text><text x="22" y="137" font-size="14" fill="#778178">{escape(b)}</text></g>''')
    if i < 3: flow.append(f'<path d="M{x+310} 173H{x+336}" fill="none" stroke="#7B897B" stroke-width="1.5" marker-end="url(#arrow)"/>')
flow.append('<text x="48" y="309" font-size="14" fill="#778178">All four steps run on your device. No account, backend or AI API key is required.</text></g></svg>')
(OUT / "reading-flow.svg").write_text("\n".join(flow), encoding="utf-8")
print("Generated hero.svg, themes.svg and reading-flow.svg")
