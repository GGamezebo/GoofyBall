"""UI concept sheets for Goofy Ball. Every screen is authored in 1600x900 (landscape phone)
and placed scaled into a phone bezel on a sheet. Run: python concept/generate_ui.py"""
import os, sys, math, random, shutil, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_concepts import C, lighten, svg, text, blob, ball, stars, court, burst

OUT = os.path.dirname(os.path.abspath(__file__))
PANEL, PANEL2, INK = "#0A1030", "#111A3F", "#170F00"
KIND = dict(primary=C['ball'], secondary=C['cyan'], accent=C['mag'], danger=C['danger'], ghost=C['sub'], buff=C['buff'])


# ---------- widgets ----------
def rr(x, y, w, h, rx=20, fill=PANEL, op=1.0, stroke=None, sw=2, sop=0.45, glow=False, dash=None):
    s = f"<rect x='{x}' y='{y}' width='{w}' height='{h}' rx='{rx}' fill='{fill}' fill-opacity='{op}'"
    if stroke:
        s += f" stroke='{stroke}' stroke-width='{sw}' stroke-opacity='{sop}'"
    if dash:
        s += f" stroke-dasharray='{dash}'"
    if glow:
        s += " filter='url(#glow)'"
    return s + "/>"

def btn(x, y, w, h, label, kind="primary", size=None, sub=None):
    col = KIND[kind]; size = size or min(int(h * 0.42), 44); rx = min(h * 0.32, 36)
    if kind == "primary":
        out = rr(x, y, w, h, rx, col, glow=True) + rr(x + 6, y + 5, w - 12, h * 0.42, rx * 0.8, "#FFFFFF", op=0.18)
        tc = INK
    else:
        out = rr(x, y, w, h, rx, col, op=0.14, stroke=col, sw=3, sop=0.9)
        tc = lighten(col, 0.55)
    ty = y + h / 2 + size * 0.36 - (size * 0.33 if sub else 0)
    out += text(x + w / 2, ty, label, size, tc)
    if sub:
        out += text(x + w / 2, ty + size * 0.85, sub, max(18, int(size * 0.5)), tc, weight="normal", extra="opacity='0.75'")
    return out

def chip(x, y, w, label, active=False, col=None, h=56, size=24):
    col = col or C['cyan']
    if active:
        return rr(x, y, w, h, h / 2, col, op=0.9) + text(x + w / 2, y + h / 2 + size * 0.36, label, size, INK)
    return rr(x, y, w, h, h / 2, PANEL2, stroke=C['sub'], sop=0.5) + text(x + w / 2, y + h / 2 + size * 0.36, label, size, C['text'], weight="normal")

def chips(x, y, labels, active=0, col=None, gap=12, size=24, h=56, widths=None):
    out = []
    for i, lab in enumerate(labels):
        w = widths[i] if widths else int(len(lab) * size * 0.62 + 44)
        out.append(chip(x, y, w, lab, i == active, col, h, size)); x += w + gap
    return "".join(out)

def iconbtn(cx, cy, r, icon, col=None, size=None):
    col = col or C['sub']
    return (f"<circle cx='{cx}' cy='{cy}' r='{r}' fill='{PANEL2}' stroke='{col}' stroke-width='3' stroke-opacity='0.7'/>"
            + text(cx, cy + (size or r) * 0.36, icon, size or r, lighten(col, 0.5)))

def bar(x, y, w, h, frac, col):
    return rr(x, y, w, h, h / 2, "#000", op=0.45) + rr(x, y, max(h, w * frac), h, h / 2, col, glow=True)

def toggle(x, y, on=True):
    col = C['lime'] if on else C['sub']
    return rr(x, y, 84, 44, 22, col, op=0.85 if on else 0.3) + f"<circle cx='{x + (62 if on else 22)}' cy='{y + 22}' r='17' fill='white'/>"

def slider(x, y, w, frac, col=None):
    col = col or C['cyan']
    return bar(x, y - 5, w, 10, frac, col) + f"<circle cx='{x + w * frac}' cy='{y}' r='18' fill='white' stroke='{col}' stroke-width='4'/>"

def marker(x, y, n):
    return f"<circle cx='{x}' cy='{y}' r='26' fill='{C['ball']}' stroke='{INK}' stroke-width='3'/>" + text(x, y + 10, n, 30, INK)

def dim(op=0.68):
    return f"<rect width='1600' height='900' fill='#00020A' opacity='{op}'/>"

def confetti(n=60, seed=7, area=(0, 0, 1600, 600)):
    rnd = random.Random(seed); cols = [C['cyan'], C['mag'], C['lime'], C['orange'], C['ball']]; out = []
    for _ in range(n):
        x = rnd.uniform(area[0], area[2]); y = rnd.uniform(area[1], area[3])
        out.append(f"<rect x='{x:.0f}' y='{y:.0f}' width='{rnd.uniform(8,16):.0f}' height='{rnd.uniform(16,28):.0f}' rx='3' fill='{rnd.choice(cols)}' opacity='0.8' transform='rotate({rnd.uniform(0,180):.0f} {x:.0f} {y:.0f})'/>")
    return "".join(out)

def hat(cx, top, col=None):
    col = col or C['ball']
    return (f"<polygon points='{cx-55},{top+18} {cx+55},{top+18} {cx+10},{top-110}' fill='{col}' stroke='white' stroke-width='4' filter='url(#glow)'/>"
            f"<circle cx='{cx+10}' cy='{top-112}' r='16' fill='white'/>")

# ---------- bars ----------
def currency(x=1120):
    return (rr(x, 28, 180, 56, 28, PANEL2, stroke=C['ball'], sop=0.5) + text(x + 90, 66, "🪙 1 250", 26)
            + rr(x + 195, 28, 140, 56, 28, PANEL2, stroke=C['cyan'], sop=0.5) + text(x + 265, 66, "💎 40", 26))

def topbar_profile():
    return (blob(78, 96, 34, C['cyan'], "happy", glow=False)
            + text(130, 58, "Slimy_42", 28, anchor="start")
            + text(130, 90, "🥈 Серебро II · 1420", 20, C['sub'], anchor="start", weight="normal")
            + rr(610, 28, 380, 64, 32, PANEL2, stroke=C['ball'], sop=0.6)
            + text(640, 60, "⭐ Сезон 3 · ур. 12", 22, C['ball'], anchor="start") + bar(640, 70, 320, 10, 0.45, C['ball'])
            + currency() + iconbtn(1540, 56, 30, "⚙"))

def topbar_back(title, money=True):
    return iconbtn(76, 60, 34, "←") + text(130, 74, title, 40, anchor="start") + (currency() + iconbtn(1540, 56, 30, "⚙") if money else "")

def navbar(active=0):
    tabs = [("🏐", "Играть"), ("🫧", "Блоб"), ("🛒", "Магазин"), ("🏆", "Рейтинг")]
    out = [f"<rect x='0' y='800' width='1600' height='100' fill='#060A1E'/>", f"<rect x='0' y='800' width='1600' height='2' fill='{C['sub']}' opacity='0.3'/>"]
    for i, (ic, lab) in enumerate(tabs):
        cx = 200 + i * 400; on = i == active; col = C['ball'] if on else C['sub']
        out.append(text(cx, 848, ic, 36, extra="" if on else "opacity='0.6'"))
        out.append(text(cx, 884, lab, 20, col, weight="bold" if on else "normal"))
        if on:
            out.append(rr(cx - 60, 802, 120, 6, 3, col, glow=True))
    return "".join(out)

def arena(nets=((800, 230),), floor=760, ceil=120, seed=3):
    return (stars(1600, 900, 50, seed)
            + f"<ellipse cx='400' cy='300' rx='380' ry='160' fill='{C['cyan']}' opacity='0.06' filter='url(#soft)'/>"
            + f"<ellipse cx='1200' cy='280' rx='380' ry='160' fill='{C['mag']}' opacity='0.06' filter='url(#soft)'/>"
            + court(60, 1540, floor, ceil, list(nets)))

def hud_score(a, b, left="YOU", right="BlobKing"):
    return (rr(650, 18, 300, 80, 24, PANEL, stroke=C['sub'], sop=0.4)
            + text(730, 76, str(a), 54, C['cyan']) + text(800, 72, ":", 44, C['sub']) + text(870, 76, str(b), 54, C['mag'])
            + text(620, 68, left, 26, C['cyan'], anchor="end") + text(980, 68, right, 26, C['mag'], anchor="start"))

def touch(icon="🍄", col=None):
    col = col or C['buff']
    return (f"<circle cx='190' cy='790' r='70' fill='white' opacity='0.05' stroke='white' stroke-opacity='0.25' stroke-width='3'/>"
            f"<circle cx='215' cy='786' r='30' fill='white' opacity='0.2'/>"
            f"<circle cx='1310' cy='805' r='60' fill='{C['cyan']}' opacity='0.15' stroke='{C['cyan']}' stroke-width='3' filter='url(#glow)'/>"
            + text(1310, 820, "⤒", 44, C['cyan'])
            + f"<circle cx='1465' cy='740' r='72' fill='{col}' opacity='0.22' stroke='{col}' stroke-width='4' filter='url(#glow)'/>"
            + text(1465, 758, icon, 48))

def pause_btn():
    return iconbtn(70, 58, 32, "⏸")


# ---------- frame & sheet ----------
FW, FH = 880, 495

def frame(x, y, title, content, notes):
    out = [text(x, y - 26, title, 28, anchor="start"),
           rr(x - 12, y - 12, FW + 24, FH + 24, 38, "#151B33", stroke="#2C3658", sw=3, sop=1),
           f"<svg x='{x}' y='{y}' width='{FW}' height='{FH}' viewBox='0 0 1600 900'><rect width='1600' height='900' fill='url(#bgG)'/>{content}</svg>"]
    for j, line in enumerate(notes):
        out.append(text(x + 4, y + FH + 46 + j * 30, line, 21, C['sub'], anchor="start", weight="normal"))
    return "".join(out)

def save(name, body):
    path = os.path.join(OUT, name + ".svg")
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
    return path

def sheet(name, title, subtitle, items):
    W = 1900; top = 170; RH = 690; n = len(items); rows = (n + 1) // 2
    H = top + rows * RH
    b = [stars(W, H, 50), text(W / 2, 72, title, 46), text(W / 2, 114, subtitle, 24, C['sub'], weight="normal")]
    for i, (t, content, notes) in enumerate(items):
        r, c = divmod(i, 2)
        x = (W - FW) / 2 if (n % 2 and i == n - 1) else (50 if c == 0 else 970)
        b.append(frame(x, top + r * RH + 40, f"{i + 1}. {t}", content, notes))
    return save(name, svg(W, H, "".join(b))), W, H


# ---------- screens: entry & home ----------
def scr_splash():
    return (stars(1600, 900, 70, 11)
            + f"<ellipse cx='800' cy='330' rx='560' ry='200' fill='{C['buff']}' opacity='0.12' filter='url(#soft)'/>"
            + text(800, 260, "GOOFY", 170, C['cyan'], extra="filter='url(#glow)' letter-spacing='12'")
            + text(800, 410, "BALL", 170, C['mag'], extra="filter='url(#glow)' letter-spacing='24'")
            + f"<rect x='560' y='690' width='480' height='4' fill='{C['cyan']}' opacity='0.6' filter='url(#glow)'/>"
            + blob(720, 600, 58, C['cyan'], "happy", 0.85, 1.15, ground=False, floor_y=690)
            + blob(900, 690, 58, C['mag'], "scared", 1.15, 0.85)
            + ball(810, 470, 28, trail=(-14, 10))
            + bar(600, 770, 400, 14, 0.6, C['ball']) + text(800, 830, "Загрузка… 60%", 24, C['sub'], weight="normal")
            + text(1560, 880, "v0.1", 18, C['sub'], anchor="end", weight="normal"))

def home_body():
    return (f"<rect x='120' y='757' width='640' height='4' fill='{C['cyan']}' opacity='0.5' filter='url(#glow)'/>"
            + f"<ellipse cx='430' cy='520' rx='300' ry='220' fill='{C['cyan']}' opacity='0.07' filter='url(#soft)'/>"
            + blob(430, 760, 140, C['cyan'], "happy", look=0.5)
            + ball(610, 300, 40)
            + rr(110, 140, 420, 64, 32, PANEL2, stroke=C['cyan'], sop=0.6)
            + text(140, 182, "🐸 Прыгун · прыжок +25%", 24, anchor="start") + text(500, 182, "✎", 26, C['cyan'])
            + rr(880, 140, 660, 84, 24, PANEL, stroke=C['mag'], sw=3, sop=0.8)
            + text(910, 176, "🏆 Кубок выходных", 28, anchor="start")
            + text(910, 208, "старт через 2ч 14м · приз: шапка", 20, C['sub'], anchor="start", weight="normal")
            + text(1505, 196, "›", 44, C['mag'])
            + rr(880, 250, 660, 70, 35, PANEL2, stroke=C['sub'], sop=0.4)
            + rr(886, 256, 324, 58, 29, C['cyan'], op=0.9) + text(1048, 296, "Быстрый", 28, INK)
            + text(1375, 296, "Ранговый", 28, C['text'], weight="normal")
            + btn(880, 340, 660, 170, "▶  ИГРАТЬ", size=72)
            + btn(880, 530, 320, 100, "🤖 Против AI", "secondary", 30)
            + btn(1220, 530, 320, 100, "👥 С другом", "secondary", 30)
            + text(1210, 690, "🟢 1 284 игрока онлайн", 22, C['sub'], weight="normal"))

def scr_home():
    return stars(1600, 900, 40, 5) + home_body() + topbar_profile() + navbar(0)

def scr_friend():
    cards = (rr(340, 260, 440, 360, 28, PANEL2, stroke=C['cyan'], sop=0.5)
             + text(560, 370, "🏠", 80) + text(560, 450, "Создать комнату", 32)
             + text(560, 490, "получишь код и ссылку", 22, C['sub'], weight="normal")
             + btn(390, 530, 340, 70, "Создать", size=30)
             + rr(820, 260, 440, 360, 28, PANEL2, stroke=C['cyan'], sop=0.5)
             + text(1040, 320, "Войти по коду", 32))
    for i, ch in enumerate("K7Q "):
        x = 857 + i * 95
        cards += rr(x, 350, 80, 100, 16, PANEL, stroke=C['ball'] if i == 3 else C['sub'], sw=3, sop=0.9)
        cards += text(x + 40, 420, ch.strip() or "|", 52, C['ball'] if i == 3 else C['text'])
    cards += text(1040, 490, "или открой ссылку от друга", 22, C['sub'], weight="normal")
    cards += btn(870, 530, 340, 70, "Войти", "secondary", 30)
    return (stars(1600, 900, 40, 5) + home_body() + topbar_profile() + navbar(0) + dim()
            + rr(300, 140, 1000, 640, 36, PANEL, stroke=C['sub'], sop=0.5)
            + text(800, 215, "Играть с другом", 42) + iconbtn(1245, 195, 30, "✕")
            + cards + btn(440, 650, 720, 90, "🎮 Вдвоём на одном ПК", "ghost", 28, sub="только PC / Steam"))

def scr_ai():
    out = [stars(1600, 900, 40, 8), topbar_back("Против AI"), text(80, 170, "Персонаж", 24, C['sub'], anchor="start")]
    chars = [("cyan", "Прыгун"), ("mag", "Толстяк"), ("lime", "Липкий"), ("orange", "Резиновый"), ("buff", "Шустрик")]
    for i, (c, n) in enumerate(chars):
        x = 80 + i * 290; on = i == 0
        out.append(rr(x, 190, 260, 230, 26, PANEL2, stroke=C['ball'] if on else C['sub'], sw=4 if on else 2, sop=1 if on else 0.4))
        out.append(blob(x + 130, 370, 62, C[c], "happy" if on else "smug", 1.25 if c == "mag" else 1.0, 0.85 if c == "mag" else 1.0, glow=on))
        out.append(text(x + 130, 405, n, 24, C['text'] if on else C['sub']))
        if on:
            out.append(f"<circle cx='{x+232}' cy='{218}' r='18' fill='{C['ball']}'/>" + text(x + 232, 227, "✓", 24, INK))
    out.append(text(80, 462, "🐸 Прыгун — прыжок +25%, но легче отлетает", 24, anchor="start", weight="normal"))
    out.append(text(80, 525, "Сложность", 22, C['sub'], anchor="start"))
    out.append(chips(80, 540, ["Лёгкий", "Средний", "Сложный", "🔥 Безумный"], 1, size=22))
    out.append(text(80, 640, "Формат", 22, C['sub'], anchor="start"))
    out.append(chips(80, 655, ["1×1", "2×2 с ботами", "3 команды"], 0, size=22))
    out.append(text(860, 525, "Арена", 22, C['sub'], anchor="start"))
    out.append(chips(860, 540, ["Неон", "Крыша", "Космос", "Кухня"], 0, C['mag'], size=22))
    out.append(text(860, 640, "Физика", 22, C['sub'], anchor="start"))
    out.append(chips(860, 655, ["Classic", "Moon", "Ice", "Bouncy", "Chaos"], 0, C['lime'], size=22))
    out.append(text(80, 830, "Всё уже выбрано — можно сразу жать «Играть»", 22, C['sub'], anchor="start", weight="normal"))
    out.append(btn(1140, 770, 400, 100, "▶ ИГРАТЬ", size=44))
    return "".join(out)


# ---------- screens: matchmaking & lobby ----------
def scr_search():
    return (stars(1600, 900, 60, 9) + text(800, 190, "Ищем соперника…", 56)
            + text(800, 265, "0:12", 46, C['ball']) + text(800, 305, "обычно ~20 с · Быстрый матч", 22, C['sub'], weight="normal")
            + f"<rect x='560' y='640' width='480' height='4' fill='{C['cyan']}' opacity='0.6' filter='url(#glow)'/>"
            + blob(800, 640, 90, C['cyan'], "happy", 1.35, 0.7, glow=False, opacity=0.12)
            + blob(800, 540, 90, C['cyan'], "happy", 0.85, 1.15, ground=False, floor_y=640)
            + text(800, 700, "💡 Совет: «Действие» без бафа = взрыв. Один раз за розыгрыш!", 22, C['sub'], weight="normal")
            + btn(620, 760, 360, 90, "Отмена", "ghost", 32))

def scr_vs():
    return (stars(1600, 900, 40, 2)
            + f"<polygon points='0,0 860,0 740,900 0,900' fill='{C['cyan']}' opacity='0.12'/>"
            + f"<polygon points='860,0 1600,0 1600,900 740,900' fill='{C['mag']}' opacity='0.12'/>"
            + f"<line x1='860' y1='0' x2='740' y2='900' stroke='white' stroke-width='6' opacity='0.6' filter='url(#glow)'/>"
            + rr(640, 80, 320, 64, 32, PANEL, stroke=C['sub'], sop=0.5) + text(800, 124, "Старт через 3", 30)
            + blob(380, 620, 130, C['cyan'], "angry", look=1) + blob(1220, 620, 130, C['mag'], "smug", 1.15, 0.9, look=-1)
            + text(800, 470, "VS", 150, C['ball'], extra="filter='url(#glow)'")
            + text(380, 700, "Slimy_42", 40, C['cyan']) + text(380, 745, "🐸 Прыгун · 1420", 24, C['sub'], weight="normal")
            + text(1220, 700, "BlobKing", 40, C['mag']) + text(1220, 745, "🐷 Толстяк · 1395", 24, C['sub'], weight="normal")
            + rr(470, 800, 660, 64, 32, PANEL, stroke=C['sub'], sop=0.4)
            + text(800, 842, "Неоновый стадион · Classic · до 7", 24, weight="normal"))

def slot(x, y, col, nick=None, ready=False, empty="+ Бот", mood="happy"):
    if nick:
        return (rr(x, y, 680, 110, 22, PANEL2, stroke=col, sop=0.6) + blob(x + 70, y + 98, 42, col, mood, glow=False)
                + text(x + 140, y + 66, nick, 30, anchor="start")
                + text(x + 650, y + 66, "готов ✓" if ready else "…", 24, C['lime'] if ready else C['sub'], anchor="end"))
    return rr(x, y, 680, 110, 22, PANEL, stroke=C['sub'], sop=0.6, dash="12 10") + text(x + 340, y + 66, empty, 28, C['sub'])

def scr_room():
    return (stars(1600, 900, 40, 4) + topbar_back("Комната", money=False)
            + rr(60, 125, 1480, 120, 26, PANEL, stroke=C['ball'], sop=0.5)
            + text(95, 165, "Код комнаты", 22, C['sub'], anchor="start", weight="normal")
            + text(95, 228, "K 7 Q X", 60, C['ball'], anchor="start")
            + btn(860, 145, 300, 80, "📋 Копировать", "secondary", 26) + btn(1180, 145, 330, 80, "🔗 Пригласить", "accent", 26)
            + text(80, 300, "Команда A", 28, C['cyan'], anchor="start") + text(840, 300, "Команда B", 28, C['mag'], anchor="start")
            + slot(60, 320, C['cyan'], "Slimy_42 👑", True) + slot(60, 445, C['cyan'])
            + slot(840, 320, C['mag'], "BlobKing", True, mood="smug") + slot(840, 445, C['mag'], empty="Ждём игрока…")
            + chips(60, 600, ["2×2 ▾", "Неон ▾", "Classic ▾", "До 7 ▾", "+ команда"], -1, size=24)
            + text(60, 720, "Настройки меняет хозяин 👑 · ссылка открывает веб-версию", 22, C['sub'], anchor="start", weight="normal")
            + btn(1140, 760, 400, 100, "СТАРТ", size=46))


# ---------- screens: match ----------
def scr_hud():
    floor = 760
    return (arena()
            + f"<rect x='0' y='300' width='800' height='600' fill='white' opacity='0.03' stroke='white' stroke-opacity='0.25' stroke-dasharray='14 12'/>"
            + blob(500, floor - 170, 66, C['cyan'], "angry", 0.9, 1.12, look=1, ground=False, floor_y=floor)
            + blob(1150, floor, 66, C['mag'], "scared", look=-1) + ball(650, 360, 34, trail=(-22, 18))
            + text(1150, floor - 160, "BlobKing", 22, C['mag'], weight="normal", extra="opacity='0.8'")
            + f"<g filter='url(#glow)'><rect x='610' y='130' width='380' height='60' rx='18' fill='{C['danger']}' opacity='0.18' stroke='{C['danger']}' stroke-width='3'/></g>"
            + text(800, 171, "⚠ Луна через 2…", 30, "#FFD0D0")
            + hud_score(4, 3) + pause_btn() + touch()
            + marker(130, 58, "1") + marker(985, 112, "2") + marker(1030, 160, "3")
            + marker(330, 330, "4") + marker(1385, 860, "5") + marker(1555, 660, "6"))

def scr_tutorial():
    floor = 760
    return (arena(seed=12)
            + blob(420, floor, 66, C['cyan'], "happy", look=1) + blob(1150, floor, 66, C['mag'], "smug", look=-1)
            + ball(520, 330, 34)
            + f"<path d='M520,330 Q600,150 760,180 T1050,420' stroke='{C['ball']}' stroke-width='4' fill='none' stroke-dasharray='6 14' opacity='0.7'/>"
            + rr(470, 130, 660, 84, 26, PANEL, stroke=C['ball'], sw=3, sop=0.9)
            + text(800, 168, "Шаг 1/3 · Отбей мяч на ту сторону", 30)
            + text(800, 202, "три касания на команду", 20, C['sub'], weight="normal")
            + rr(1380, 30, 190, 56, 28, PANEL2, stroke=C['sub'], sop=0.5) + text(1475, 66, "Пропустить", 22, C['sub'], weight="normal")
            + touch("💥", C['danger'])
            + f"<path d='M120,700 L80,700 M300,700 L340,700' stroke='{C['ball']}' stroke-width='6' stroke-linecap='round'/>"
            + f"<polygon points='60,700 90,684 90,716' fill='{C['ball']}'/><polygon points='360,700 330,684 330,716' fill='{C['ball']}'/>"
            + text(210, 720, "👆", 64) + text(210, 640, "Тяни влево-вправо", 26, C['ball'])
            + f"<circle cx='1310' cy='805' r='86' fill='none' stroke='{C['ball']}' stroke-width='5' opacity='0.8' filter='url(#glow)'/>"
            + text(1310, 690, "Прыжок!", 30, C['ball']))

def scr_multi():
    floor = 760; nets = ((553, 210), (1046, 210))
    out = [arena(nets, seed=6)]
    zones = [(60, 493, C['cyan'], "❤❤❤", "happy"), (553, 493, C['mag'], "❤🖤🖤", "scared"), (1046, 494, C['lime'], "❤❤🖤", "angry")]
    for i, (x, w, col, hearts, mood) in enumerate(zones):
        out.append(f"<rect x='{x}' y='120' width='{w}' height='{floor-120}' fill='{col}' opacity='0.05'/>")
        out.append(rr(x + w / 2 - 120, 20, 240, 70, 22, PANEL, stroke=col, sw=3, sop=0.8) + text(x + w / 2, 68, hearts, 34, col))
        out.append(blob(x + w / 2, floor, 56, col, mood))
    out.append(ball(790, 380, 30, trail=(18, -14)))
    out.append(pause_btn() + touch("🌀"))
    return "".join(out)

def scr_point():
    floor = 760
    return (arena(seed=14)
            + f"<rect x='860' y='120' width='420' height='70' fill='#3A4466' stroke='{C['sub']}' stroke-width='3'/>"
            + f"<polygon points='880,560 1250,520 1260,610 870,640' fill='#3A4466' stroke='white' stroke-width='4' filter='url(#glow)'/>"
            + blob(1060, floor, 70, C['mag'], "dead", 1.9, 0.35)
            + blob(420, floor, 66, C['cyan'], "smug", look=1)
            + burst(1060, 650, 120, C['ball'], 10)
            + "<rect width='1600' height='70' fill='#000'/><rect y='830' width='1600' height='70' fill='#000'/>"
            + f"<circle cx='60' cy='35' r='12' fill='{C['danger']}'/>" + text(85, 46, "ПОВТОР 0.5×", 28, "#FFD0D0", anchor="start")
            + text(800, 330, "ОЧКО!", 130, C['cyan'], extra="filter='url(#glow)'")
            + text(800, 410, "5 : 3", 52)
            + rr(1150, 740, 400, 70, 35, PANEL, stroke=C['ball'], sw=3, sop=0.9)
            + text(1350, 785, "★ Момент сохранён", 26, C['ball']))

def match_bg():
    return (arena(seed=3) + blob(500, 760, 66, C['cyan'], "happy") + blob(1150, 760, 66, C['mag'], "smug", look=-1)
            + ball(800, 400, 34) + hud_score(4, 3) + pause_btn() + touch())

def scr_pause():
    return (match_bg() + dim()
            + rr(520, 130, 560, 660, 36, PANEL, stroke=C['sub'], sop=0.5) + text(800, 215, "Пауза", 52)
            + btn(580, 260, 440, 110, "▶ Продолжить", size=38)
            + btn(580, 400, 440, 95, "⚙ Настройки", "secondary", 32)
            + btn(580, 525, 440, 95, "🚪 Выйти", "danger", 32)
            + text(800, 680, "Офлайн — игра на паузе.", 22, C['sub'], weight="normal")
            + text(800, 714, "Онлайн — это просто меню, матч идёт.", 22, C['sub'], weight="normal"))

def scr_reconnect():
    dots = "".join(f"<circle cx='{740 + i*60}' cy='470' r='14' fill='{C['cyan']}' opacity='{0.3 + i*0.3}'/>" for i in range(3))
    return (match_bg() + dim(0.55)
            + rr(420, 230, 760, 400, 36, PANEL, stroke=C['orange'], sw=3, sop=0.8)
            + text(800, 320, "📶 BlobKing потерял связь", 38) + dots
            + text(800, 550, "Ждём 0:08 · не вернётся — победа твоя", 26, C['sub'], weight="normal")
            + rr(1210, 140, 340, 64, 32, PANEL, stroke=C['danger'], sop=0.7) + text(1380, 182, "📶 у тебя 180 мс", 24, "#FFD0D0"))


# ---------- screens: results ----------
def scr_result(win=True):
    col = C['ball'] if win else C['mag']
    out = [stars(1600, 900, 40, 21)]
    if win:
        out.append(confetti())
    out.append(text(430, 170, "ПОБЕДА!" if win else "ПОРАЖЕНИЕ", 96 if win else 80, col, extra="filter='url(#glow)'"))
    out.append(text(430, 255, "7 : 4" if win else "5 : 7", 56))
    out.append(f"<rect x='150' y='757' width='560' height='4' fill='{C['cyan']}' opacity='0.5' filter='url(#glow)'/>")
    if win:
        out.append(blob(430, 760, 140, C['cyan'], "smug", look=0.5) + text(430, 470, "👑", 90))
    else:
        out.append(blob(430, 760, 120, C['cyan'], "dead", 1.5, 0.55))
    rating = ("1420 → 1438", "+18", C['lime']) if win else ("1420 → 1408", "−12", C['danger'])
    out.append(rr(880, 60, 660, 100, 24, PANEL, stroke=C['sub'], sop=0.4)
               + text(910, 96, "Рейтинг", 22, C['sub'], anchor="start", weight="normal")
               + text(910, 140, rating[0], 36, anchor="start") + text(1510, 130, rating[1], 46, rating[2], anchor="end"))
    out.append(rr(880, 175, 660, 100, 24, PANEL, stroke=C['sub'], sop=0.4)
               + text(910, 211, "⭐ Сезон · ур. 12", 22, C['ball'], anchor="start")
               + text(1510, 211, "+120 XP" if win else "+60 XP", 22, C['ball'], anchor="end") + bar(910, 235, 600, 14, 0.62, C['ball']))
    out.append(rr(880, 290, 660, 100, 24, PANEL, stroke=C['sub'], sop=0.4)
               + text(910, 355, "🪙 +50" if win else "🪙 +20", 36, anchor="start")
               + btn(1220, 305, 300, 70, "▶ ×2 за видео", "buff", 24))
    out.append(rr(880, 405, 660, 220, 24, PANEL, stroke=C['mag'], sw=3, sop=0.8)
               + rr(905, 430, 280, 170, 16, "#000", op=0.6)
               + f"<polygon points='930,560 1150,535 1155,575 925,590' fill='#3A4466' stroke='white' stroke-width='3'/>"
               + blob(1045, 598, 30, C['mag'], "dead", 1.8, 0.4, glow=False) + text(1045, 525, "▶", 50, "white", extra="opacity='0.85'")
               + text(1210, 470, "Лучший момент", 24, C['sub'], anchor="start", weight="normal")
               + text(1210, 510, "Потолок раздавил" if win else "Взрыв в упор", 28, anchor="start")
               + text(1210, 545, "BlobKing 💀" if win else "в свою сетку 🤦", 28, anchor="start")
               + btn(1210, 560, 310, 52, "📤 Поделиться", "accent", 24))
    if win:
        out.append(btn(880, 660, 310, 110, "↻ Реванш", "secondary", 32) + btn(1210, 660, 330, 110, "Дальше ›", size=38))
    else:
        out.append(btn(880, 660, 330, 110, "↻ Реванш", size=38) + btn(1230, 660, 310, 110, "Дальше ›", "secondary", 32))
        out.append(text(1210, 820, "💡 Толстяк плохо прыгает — бей высоко", 22, C['sub'], weight="normal"))
    return "".join(out)

def scr_share():
    x0, y0, w, h = 620, 120, 360, 640
    phone = (f"<svg x='{x0}' y='{y0}' width='{w}' height='{h}' viewBox='0 0 360 640'>"
             f"<rect width='360' height='640' fill='url(#bgG)'/>" + stars(360, 640, 20, 30)
             + text(180, 50, "GOOFY BALL", 28, C['ball'], extra="filter='url(#glow)'")
             + f"<rect x='10' y='540' width='340' height='4' fill='{C['cyan']}' filter='url(#glow)'/>"
             + f"<rect x='10' y='120' width='340' height='40' fill='#3A4466'/>"
             + f"<polygon points='150,420 330,400 335,450 145,470' fill='#3A4466' stroke='white' stroke-width='3' filter='url(#glow)'/>"
             + blob(250, 540, 45, C['mag'], "dead", 1.9, 0.35) + blob(90, 540, 45, C['cyan'], "smug", look=1)
             + burst(250, 480, 70, C['ball'], 10)
             + text(180, 600, "когда потолок решил за тебя 💀", 20)
             + "</svg>")
    return (stars(1600, 900, 40, 31) + topbar_back("Поделиться клипом", money=False)
            + rr(x0 - 10, y0 - 10, w + 20, h + 20, 30, "#151B33", stroke="#2C3658", sw=3, sop=1) + phone
            + bar(x0, 800, w, 12, 1.0, C['mag']) + rr(x0 + 40, 790, 14, 32, 7, "white") + rr(x0 + 300, 790, 14, 32, 7, "white")
            + text(800, 860, "15 с · 9:16", 22, C['sub'], weight="normal")
            + text(80, 230, "Слоумо в конце", 28, anchor="start") + toggle(460, 202, True)
            + text(80, 320, "Подпись", 28, anchor="start") + toggle(460, 292, True)
            + text(80, 410, "Ссылка «сыграй со мной»", 28, anchor="start") + toggle(460, 382, True)
            + text(80, 500, "Ник на видео", 28, anchor="start") + toggle(460, 472, False)
            + btn(1060, 200, 480, 120, "📤 Поделиться…", size=38, sub="системное меню: TikTok, Shorts, Reels")
            + btn(1060, 350, 480, 100, "💾 Сохранить видео", "secondary", 30)
            + btn(1060, 480, 480, 100, "🔗 Вызов другу", "accent", 30)
            + text(1300, 620, "Ссылка открывает игру в браузере", 22, C['sub'], weight="normal"))

def scr_rankup():
    shield = "M800,190 L940,240 L925,420 Q900,520 800,560 Q700,520 675,420 L660,240 Z"
    return (scr_result(True) + dim(0.9) + confetti(40, 3, (320, 40, 1280, 170))
            + f"<path d='{shield}' fill='{C['ball']}' opacity='0.25' stroke='{C['ball']}' stroke-width='6' filter='url(#glowBig)'/>"
            + text(800, 420, "🥇", 130)
            + text(800, 630, "Новый ранг!", 46, C['sub'])
            + text(800, 700, "Золото III", 64, C['ball'], extra="filter='url(#glow)'")
            + text(800, 750, "награда: золотая рамка профиля", 24, C['sub'], weight="normal")
            + btn(620, 780, 360, 90, "Круто!", size=38))


# ---------- screens: meta ----------
def scr_blob():
    out = [stars(1600, 900, 40, 41), topbar_back("Блоб"),
           f"<rect x='90' y='757' width='560' height='4' fill='{C['cyan']}' opacity='0.5' filter='url(#glow)'/>",
           f"<ellipse cx='370' cy='520' rx='280' ry='220' fill='{C['cyan']}' opacity='0.07' filter='url(#soft)'/>",
           blob(370, 760, 150, C['cyan'], "smug", look=0.4), hat(390, 470),
           text(370, 820, "🐸 Прыгун · «Звёздный» · Колпак", 24, C['sub'], weight="normal"),
           chips(720, 125, ["Персонаж", "Скин", "Шапка", "Руки/ноги", "Мяч", "Победа"], 2, C['ball'], 10, 22, 54)]
    items = [("✓", C['ball'], 0), ("", C['orange'], 0), ("", C['lime'], 0), ("🔒 300", C['mag'], 1),
             ("🔒 Сезон", C['buff'], 2), ("🔒 500", C['cyan'], 1), ("🔒 ▶", C['orange'], 1), ("🔒 Кубок", C['danger'], 2)]
    for i, (lab, col, st) in enumerate(items):
        x = 720 + (i % 4) * 205; y = 210 + (i // 4) * 255; on = i == 3
        out.append(rr(x, y, 185, 235, 22, PANEL2, stroke=C['ball'] if on else C['sub'], sw=4 if on else 2, sop=1 if on else 0.4))
        out.append(f"<polygon points='{x+52},{y+150} {x+132},{y+150} {x+102},{y+40}' fill='{col}' stroke='white' stroke-width='3' opacity='{0.55 if st else 1}'/>")
        out.append(f"<circle cx='{x+102}' cy='{y+40}' r='12' fill='white' opacity='{0.55 if st else 1}'/>")
        out.append(text(x + 92, y + 205, lab or "есть", 22, C['ball'] if lab == "✓" else (C['text'] if lab else C['sub']), weight="bold" if lab else "normal"))
    out.append(text(720, 830, "Только внешний вид — на игру не влияет", 22, C['sub'], anchor="start", weight="normal"))
    out.append(btn(1170, 770, 370, 100, "Купить · 300 🪙", size=34))
    return "".join(out)

def offer(x, y, w, h, title, sub, price, art, kind="primary", badge=None):
    out = rr(x, y, w, h, 26, PANEL2, stroke=C['sub'], sop=0.4) + art
    if badge:
        out += rr(x + 20, y + 20, 150, 40, 20, C['mag'], op=0.9) + text(x + 95, y + 48, badge, 20, "white")
    out += text(x + w / 2, y + h - 135, title, 28) + text(x + w / 2, y + h - 100, sub, 20, C['sub'], weight="normal")
    return out + btn(x + 30, y + h - 80, w - 60, 62, price, kind, 26)

def scr_shop():
    return (stars(1600, 900, 40, 51) + topbar_back("Магазин")
            + text(60, 160, "Предложения дня · обновятся через 6ч", 22, C['sub'], anchor="start", weight="normal")
            + offer(60, 180, 470, 370, "Скин «Лава»", "блоб", "450 🪙", blob(295, 360, 80, C['orange'], "smug"), badge="−30%")
            + offer(565, 180, 470, 370, "Мяч «Арбуз»", "мяч", "300 🪙", f"<circle cx='800' cy='290' r='70' fill='{C['lime']}' stroke='white' stroke-width='5' filter='url(#glow)'/>")
            + offer(1070, 180, 470, 370, "Перчатки", "руки/ноги", "40 💎", f"<ellipse cx='1260' cy='290' rx='48' ry='40' fill='{C['danger']}' stroke='white' stroke-width='4'/><ellipse cx='1360' cy='290' rx='48' ry='40' fill='{C['danger']}' stroke='white' stroke-width='4'/>", "secondary")
            + offer(60, 580, 470, 300, "Без рекламы", "навсегда", "299 ₽", text(295, 650, "🚫📺", 54))
            + offer(565, 580, 470, 300, "Батл-пасс", "Сезон 3 · премиум", "499 ₽", text(800, 650, "👑", 54))
            + offer(1070, 580, 470, 300, "Бесплатно", "осталось 3 из 5", "▶ Видео → 🪙 +50", text(1305, 650, "🎁", 54), "buff"))

def scr_pass():
    out = [stars(1600, 900, 40, 61), topbar_back("Батл-пасс · Сезон 3"),
           text(60, 165, "осталось 21 д · только косметика", 22, C['sub'], anchor="start", weight="normal"),
           text(150, 340, "Бесплатно", 24, C['text'], weight="normal"), text(150, 540, "👑 Премиум", 24, C['ball']),
           bar(270, 215, 1270, 12, 0.36, C['ball'])]
    free = ["🪙", "🎩", "🪙", "🧢", "💎", "🪙", "🎨"]; prem = ["🧤", "✨", "🐉", "💎", "🏐", "🎆", "👑"]
    for i in range(7):
        lv = 10 + i; x = 290 + i * 180; got = lv < 12; cur = lv == 12
        out.append(f"<circle cx='{x+70}' cy='221' r='26' fill='{C['ball'] if lv <= 12 else PANEL2}' stroke='{C['ball']}' stroke-width='3'/>")
        out.append(text(x + 70, 231, str(lv), 24, INK if lv <= 12 else C['sub']))
        for row, ic in ((0, free[i]), (1, prem[i])):
            y = 270 + row * 200
            st = C['ball'] if cur else C['sub']
            out.append(rr(x, y, 140, 160, 20, PANEL2, stroke=st, sw=4 if cur else 2, sop=1 if cur else 0.4))
            out.append(text(x + 70, y + 95, ic, 56, extra="opacity='0.45'" if got or row == 1 else ""))
            if got and row == 0:
                out.append(text(x + 70, y + 145, "✓", 28, C['lime']))
            elif row == 1:
                out.append(text(x + 70, y + 145, "🔒", 24))
            elif cur:
                out.append(text(x + 70, y + 145, "Забрать", 22, C['ball']))
    out.append(text(60, 760, "XP за любые матчи · задания недели +300 XP", 22, C['sub'], anchor="start", weight="normal"))
    out.append(btn(1140, 720, 400, 110, "Премиум · 499 ₽", size=34))
    return "".join(out)

def rating_tabs(active):
    return (topbar_back("Рейтинг")
            + rr(60, 125, 520, 66, 33, PANEL2, stroke=C['sub'], sop=0.4)
            + rr(66 + 254 * active, 131, 254, 54, 27, C['cyan'], op=0.9)
            + text(193, 168, "Лидерборд", 26, INK if active == 0 else C['text'], weight="bold" if active == 0 else "normal")
            + text(447, 168, "Кубки", 26, INK if active == 1 else C['text'], weight="bold" if active == 1 else "normal"))

def lb_row(y, rank, nick, col, rating, badge, me=False):
    return (rr(60, y, 1480, 92, 20, C['cyan'] if me else PANEL2, op=0.18 if me else 1, stroke=C['cyan'] if me else None, sw=3, sop=0.9)
            + text(130, y + 60, rank, 32 if not me else 26, C['ball'] if rank in ("🥇", "🥈", "🥉") else C['text'])
            + blob(240, y + 84, 32, col, "smug" if not me else "happy", glow=False)
            + text(300, y + 58, nick, 30, anchor="start") + text(1180, y + 58, badge, 24, C['sub'], anchor="end", weight="normal")
            + text(1500, y + 60, rating, 32, C['ball'], anchor="end"))

def scr_leader():
    rows = [("🥇", "BlobKing", C['mag'], "2 410", "💎 Алмаз I"), ("🥈", "JellyBoi", C['lime'], "2 388", "💎 Алмаз I"),
            ("🥉", "SquishMaster", C['orange'], "2 301", "💎 Алмаз II"), ("4", "Splat", C['buff'], "2 254", "🏅 Платина I"),
            ("5", "GooGoo", C['cyan'], "2 230", "🏅 Платина I")]
    out = [stars(1600, 900, 40, 71), rating_tabs(0),
           chips(700, 128, ["Глобальный", "Неделя", "Друзья", "🇷🇺 Страна"], 0, size=22, h=60)]
    out += [lb_row(215 + i * 104, *r) for i, r in enumerate(rows)]
    out.append(lb_row(780, "#1 284", "Slimy_42 · ты", C['cyan'], "1 420", "🥈 Серебро II", me=True))
    return "".join(out)

def cup(y, title, info, timer, col, action, kind):
    return (rr(60, y, 1480, 170, 26, PANEL2, stroke=col, sw=3, sop=0.7)
            + text(130, y + 100, "🏆", 64) + text(210, y + 70, title, 34, anchor="start")
            + text(210, y + 112, info, 22, C['sub'], anchor="start", weight="normal")
            + text(210, y + 145, timer, 22, col, anchor="start")
            + (btn(1180, y + 45, 330, 84, action, kind, 30) if action else ""))

def scr_cups():
    return (stars(1600, 900, 40, 81) + rating_tabs(1)
            + cup(220, "Кубок выходных", "сетка на 16 · 1×1 · Classic · приз: шапка «Корона»", "старт через 2ч 14м", C['ball'], "Записаться", "primary")
            + cup(410, "Часовой турнир", "по времени: больше побед за час · 34 игрока", "● идёт · 0:42 осталось", C['lime'], "Войти", "secondary")
            + cup(600, "Кубок блогера SLIMY", "код автора · 2×2 · Chaos · приз: скин мяча", "скоро · 12 окт", C['mag'], "Напомнить", "ghost"))

def scr_settings():
    tabs = ["🎮 Управление", "🔊 Звук", "✨ Графика", "🌐 Язык", "👤 Аккаунт"]
    out = [stars(1600, 900, 40, 91), topbar_back("Настройки", money=False)]
    for i, t in enumerate(tabs):
        on = i == 0
        out.append(rr(60, 130 + i * 92, 340, 76, 22, C['cyan'] if on else PANEL2, op=0.9 if on else 1, stroke=None if on else C['sub'], sop=0.3))
        out.append(text(90, 178 + i * 92, t, 26, INK if on else C['text'], anchor="start", weight="bold" if on else "normal"))
    out.append(rr(440, 130, 560, 315, 22, "#000", op=0.35, stroke=C['sub'], sop=0.5))
    out.append(f"<rect x='460' y='390' width='520' height='3' fill='{C['cyan']}' opacity='0.6'/>")
    out.append(f"<circle cx='530' cy='395' r='34' fill='white' opacity='0.08' stroke='white' stroke-opacity='0.4' stroke-width='3' stroke-dasharray='8 6'/>")
    out.append(f"<circle cx='880' cy='400' r='30' fill='{C['cyan']}' opacity='0.25' stroke='{C['cyan']}' stroke-width='3' stroke-dasharray='8 6'/>")
    out.append(f"<circle cx='950' cy='345' r='36' fill='{C['buff']}' opacity='0.25' stroke='{C['buff']}' stroke-width='3' stroke-dasharray='8 6'/>")
    out.append(text(720, 220, "✋ перетащи кнопки", 26, C['ball']))
    sl = [("Размер кнопок", 0.6), ("Прозрачность", 0.35)]
    for i, (lab, f) in enumerate(sl):
        y = 170 + i * 110
        out.append(text(1040, y, lab, 26, anchor="start") + slider(1060, y + 45, 460, f))
    tg = [("Левша (зеркально)", False), ("Вибрация", True), ("Подсказки кнопок", True)]
    for i, (lab, on) in enumerate(tg):
        y = 480 + i * 90
        out.append(text(440, y + 32, lab, 28, anchor="start") + toggle(900, y, on))
    out.append(text(1040, 512, "PC: клавиши и геймпад —", 22, C['sub'], anchor="start", weight="normal"))
    out.append(text(1040, 545, "переназначение здесь же", 22, C['sub'], anchor="start", weight="normal"))
    out.append(btn(1100, 760, 440, 90, "Сбросить", "ghost", 28))
    return "".join(out)


# ---------- navigation map ----------
def sheet_flow():
    W, H = 1900, 1260
    out = [stars(W, H, 50), text(W / 2, 72, "UI — карта экранов", 46),
           text(W / 2, 114, "жёлтый путь — главный сценарий: от запуска до матча за 1 тап", 24, C['sub'], weight="normal"),
           "<defs>"
           + "".join(f"<marker id='ar{k}' viewBox='0 0 10 10' refX='9' refY='5' markerWidth='7' markerHeight='7' orient='auto-start-reverse'><path d='M0,0 L10,5 L0,10 z' fill='{c}'/></marker>"
                     for k, c in (("Y", C['ball']), ("S", C['sub'])))
           + "</defs>"]
    NW, NH = 280, 96
    nodes = {"load": (190, 300, "Загрузка", "гостевой вход", C['sub']), "tut": (190, 500, "Обучение", "только 1-й запуск", C['sub']),
             "home": (560, 400, "Главная", "ИГРАТЬ · AI · друг", C['ball']),
             "search": (930, 240, "Поиск", "быстрый / ранговый", C['ball']), "ai": (930, 400, "Против AI", "всё по умолчанию", C['cyan']),
             "room": (930, 560, "Комната", "код · ссылка", C['cyan']),
             "vs": (1300, 240, "VS", "3 с до старта", C['ball']), "match": (1300, 400, "Матч", "счёт · 2 кнопки", C['ball']),
             "pause": (1300, 560, "Пауза / меню", "", C['sub']),
             "res": (1670, 400, "Итоги", "реванш · дальше", C['ball']), "clip": (1670, 560, "Клип", "поделиться", C['mag']),
             "rank": (1670, 240, "Новый ранг", "попап, редко", C['sub'])}
    def edge(a, b, col="S", dash=False, both=False, side="h"):
        ax, ay = nodes[a][:2]; bx, by = nodes[b][:2]
        if side == "h":
            x1, y1, x2, y2 = ax + NW / 2, ay, bx - NW / 2 - 4, by; mx = (x1 + x2) / 2
            d = f"M{x1},{y1} C{mx},{y1} {mx},{y2} {x2},{y2}"
        else:
            sgn = 1 if by > ay else -1
            d = f"M{ax},{ay + sgn*NH/2 + (sgn*4 if both else 0)} L{bx},{by - sgn*NH/2 - sgn*4}"
        c = C['ball'] if col == "Y" else C['sub']
        return (f"<path d='{d}' stroke='{c}' stroke-width='{5 if col == 'Y' else 3}' fill='none' opacity='0.9'"
                + (" stroke-dasharray='10 8'" if dash else "") + f" marker-end='url(#ar{col})'"
                + (f" marker-start='url(#ar{col})'" if both else "") + "/>")
    out += [edge("load", "home"), edge("load", "tut", dash=True, side="v"), edge("tut", "home"),
            edge("home", "search", "Y"), edge("home", "ai"), edge("home", "room"),
            edge("search", "vs", "Y"), edge("ai", "vs"), edge("room", "vs"),
            edge("vs", "match", "Y", side="v"), edge("match", "pause", both=True, side="v"),
            edge("match", "res", "Y"), edge("res", "clip", side="v"), edge("res", "rank", dash=True, side="v")]
    out.append(text(700, 250, "1 тап", 26, C['ball'], anchor="end"))
    for k, (x, y, t, s, col) in nodes.items():
        big = k == "home"
        out.append(rr(x - NW / 2, y - NH / 2, NW, NH, 24, PANEL, stroke=col, sw=5 if big else 3, sop=0.95, glow=big))
        out.append(text(x, y - (2 if s else -10), t, 30))
        if s:
            out.append(text(x, y + 30, s, 20, C['sub'], weight="normal"))
    out.append(text(1670, 650, "Реванш → VS · Дальше → Главная", 20, C['sub'], weight="normal"))
    # bus to tabs
    tabs = [("🫧 Блоб", "персонаж · скины"), ("🛒 Магазин", "косметика · без рекламы"), ("🏆 Рейтинг", "лидерборд · кубки"),
            ("⭐ Батл-пасс", "из шапки"), ("⚙ Настройки", "из шапки и паузы")]
    out.append(f"<path d='M560,{400 + NH/2} L560,730 M190,730 L1630,730' stroke='{C['sub']}' stroke-width='3' fill='none'/>")
    out.append(text(580, 715, "нижняя навигация и шапка главной", 20, C['sub'], anchor="start", weight="normal"))
    for i, (t, s) in enumerate(tabs):
        x = 190 + i * 360
        out.append(f"<path d='M{x},730 L{x},{776}' stroke='{C['sub']}' stroke-width='3' marker-end='url(#arS)'/>")
        out.append(rr(x - 150, 780, 300, NH, 24, PANEL, stroke=C['cyan'], sw=3, sop=0.7))
        out.append(text(x, 820, t, 28) + text(x, 852, s, 20, C['sub'], weight="normal"))
    # principles
    pr = ["1. Одна главная кнопка «ИГРАТЬ» — 1 тап до поиска.",
          "2. У всего есть значение по умолчанию — можно не настраивать.",
          "3. Глубина ≤ 2: вкладка → экран. Модалки — для коротких выборов.",
          "4. Главное действие справа снизу, под большой палец; кнопки ≥ 88 px.",
          "5. В матче почти нет UI: счёт, пауза, 2 кнопки. Остальное — в мире.",
          "6. Цвет = смысл: жёлтый — главное, циан — второе, маджента — поделиться.",
          "7. Иконка + 1–2 слова: читается без звука и почти без языка.",
          "8. Один макет для тача, мыши и геймпада (фокус-рамка, хоткеи на PC).",
          "9. Покупки не мешают игре: нет попапов перед матчем, нет рекламы в ранговых.",
          "10. Смешной момент → «★ сохранён» → одна кнопка «Поделиться» в итогах."]
    out.append(rr(50, 930, 1800, 300, 30, PANEL, stroke=C['ball'], sw=3, sop=0.5))
    out.append(text(90, 980, "ПРИНЦИПЫ UI", 26, C['ball'], anchor="start"))
    for i, p in enumerate(pr):
        out.append(text(90 + (i // 5) * 900, 1030 + (i % 5) * 40, p, 22, anchor="start", weight="normal"))
    return save("ui-flow", svg(W, H, "".join(out))), W, H


# ---------- sheets ----------
def build():
    yield sheet_flow()
    yield sheet("ui-home", "UI — вход и главная", "главный экран = персонаж слева, одна большая кнопка справа", [
        ("Загрузка", scr_splash(), ["Гостевой вход без регистрации. Первый запуск → сразу обучение,", "без экранов «введите ник» и соглашений-стен."]),
        ("Главная", scr_home(), ["Справа: режим (Быстрый/Ранговый) → ИГРАТЬ. Ниже — AI и друг.", "Тап по блобу или «✎» → вкладка «Блоб». Шапка: профиль, сезон, валюта, ⚙.", "Баннер кубка — единственное «событие» на главной."]),
        ("С другом", scr_friend(), ["Модалка из двух вариантов: создать или войти по коду.", "Ссылка-приглашение открывает комнату сразу (в вебе — без установки).", "«Вдвоём на одном ПК» — только PC; на мобильных кнопки нет."]),
        ("Против AI", scr_ai(), ["Один экран вместо мастера из шагов. Всё выбрано по умолчанию", "(последний выбор запоминается) — «Играть» можно жать сразу.", "Этот же экран — шаблон настроек комнаты и будущей кампании."]),
    ])
    yield sheet("ui-lobby", "UI — поиск, VS и комната", "между тапом «Играть» и матчем — максимум два экрана", [
        ("Поиск соперника", scr_search(), ["Таймер и ожидаемое время. Блоб прыгает — экран не «висит».", "Отмена — крупная, снизу по центру. Совет дня обучает механикам."]),
        ("VS", scr_vs(), ["3 секунды: ники, персонажи, рейтинг, арена и пресет.", "Цвет команды = цвет блоба в матче. Тап ничего не делает — просто отсчёт."]),
        ("Комната", scr_room(), ["Код огромный — его диктуют голосом. «Пригласить» = системный шаринг.", "Слоты по командам; пустой слот → «+ Бот». N команд × N игроков.", "Настройки — чипы-выпадашки в одну строку, меняет только хозяин."]),
    ])
    yield sheet("ui-match", "UI — матч", "минимум интерфейса: всё важное — внутри арены", [
        ("HUD 1×1", scr_hud(), ["1 пауза (онлайн — меню) · 2 счёт и ники · 3 плашка события за 1–2 с", "4 движение: вся левая половина, drag от точки касания · 5 прыжок", "6 «Действие»: иконка бафа в слоте, пусто → 💥 самоуничтожение"]),
        ("Обучение (1-й запуск)", scr_tutorial(), ["Настоящий матч против AI с подсказками поверх: 3 шага —", "движение, прыжок, «Действие». Можно пропустить в любой момент."]),
        ("3 команды", scr_multi(), ["Вместо счёта — жизни каждой команды над её зоной.", "Плашки в цвете команды. Выбывшая зона гаснет и схлопывается."]),
        ("Очко + повтор", scr_point(), ["После яркого очка: кино-полосы, слоумо 0.5×, «ОЧКО!» и новый счёт.", "Момент сам сохраняется для клипа — ничего нажимать не нужно."]),
        ("Пауза", scr_pause(), ["Три большие кнопки, «Продолжить» — главная.", "Выход из онлайн-матча — с подтверждением (засчитывается поражение)."]),
        ("Переподключение", scr_reconnect(), ["Соперник отвалился — честный таймер и понятный исход.", "Свой плохой пинг — маленькая плашка справа сверху, не мешает игре."]),
    ])
    yield sheet("ui-results", "UI — итоги и клипы", "после матча: результат, награды и одна кнопка «Поделиться»", [
        ("Победа", scr_result(True), ["Слева эмоция (блоб-победитель), справа цифры: рейтинг, XP, монеты.", "«Лучший момент» с превью — главный вирусный крючок.", "«Дальше» — главная, «Реванш» — второй по важности."]),
        ("Поражение", scr_result(False), ["Та же раскладка. Главная кнопка — «Реванш».", "Совет против персонажа соперника вместо пустого «Вы проиграли»."]),
        ("Поделиться клипом", scr_share(), ["Превью 9:16 с водяным знаком и подписью. 4 переключателя, без редактора.", "Одна главная кнопка → системное меню шаринга (без логотипов соцсетей).", "«Вызов другу» — ссылка, которая открывает веб-версию."]),
        ("Новый ранг", scr_rankup(), ["Редкий попап поверх итогов: ранг + награда, одна кнопка.", "Не больше одного попапа за раз; очередь наград — по порядку."]),
    ])
    yield sheet("ui-meta", "UI — блоб, магазин, рейтинг, настройки", "вкладки нижней навигации и экраны из шапки", [
        ("Блоб", scr_blob(), ["Слева примерка, справа сетка. Тап по предмету = надеть сразу.", "Замок показывает способ получения: цена, сезон, кубок, видео."]),
        ("Магазин", scr_shop(), ["Сверху 3 предложения дня, снизу постоянные: без рекламы, пасс, видео.", "Только косметика. Никаких сундуков за деньги."]),
        ("Батл-пасс", scr_pass(), ["Горизонтальная дорожка: бесплатная и премиум линейки.", "Текущий уровень подсвечен, «Забрать» — прямо в ячейке."]),
        ("Рейтинг · лидерборд", scr_leader(), ["Две вкладки: Лидерборд и Кубки. Фильтры — чипами.", "Своя строка всегда закреплена внизу."]),
        ("Рейтинг · кубки", scr_cups(), ["Карточка кубка: формат, приз, таймер, одна кнопка.", "Цвет таймера = статус: скоро / идёт / анонс."]),
        ("Настройки", scr_settings(), ["Слева разделы, справа содержимое. Управление — первым:", "кнопки двигаются прямо на превью, размер и прозрачность — ползунки."]),
    ])


def find_browser():
    for c in ("chromium", "chromium-browser", "google-chrome", "chrome", "msedge",
              r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
              r"C:\Program Files\Google\Chrome\Application\chrome.exe"):
        p = shutil.which(c) or (c if os.path.isfile(c) else None)
        if p:
            return p

if __name__ == "__main__":
    browser = find_browser()
    for path, w, h in build():
        if browser:
            subprocess.run([browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                            f"--window-size={w},{h}", f"--screenshot={path[:-4]}.png", "file:///" + path.replace("\\", "/")],
                           check=True, capture_output=True)
        print("ok", os.path.basename(path), "+png" if browser else "")
