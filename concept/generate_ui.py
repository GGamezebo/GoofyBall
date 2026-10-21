"""UI concept sheets for Goofy Ball. Every screen is authored in 1600x900 (landscape phone)
and placed scaled into a phone bezel on a sheet; the same screens also build the clickable
ui-prototype.html. Run: python concept/generate_ui.py"""
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
            + rr(600, 28, 400, 60, 30, PANEL2, stroke=C['ball'], sop=0.6)
            + text(630, 68, "📋 Задания 1/3", 24, anchor="start") + text(975, 68, "×2 🏆", 22, C['lime'], anchor="end")
            + f"<circle cx='992' cy='34' r='10' fill='{C['danger']}'/>"
            + currency() + iconbtn(1540, 56, 30, "⚙"))

def topbar_back(title, money=True):
    return iconbtn(76, 60, 34, "←") + text(130, 74, title, 40, anchor="start") + (currency() + iconbtn(1540, 56, 30, "⚙") if money else "")

def navbar(active=0):
    tabs = [("🏐", "Играть"), ("👥", "Друзья"), ("🫧", "Блоб"), ("🛒", "Магазин"), ("🏆", "Рейтинг")]
    out = [f"<rect x='0' y='800' width='1600' height='100' fill='#060A1E'/>", f"<rect x='0' y='800' width='1600' height='2' fill='{C['sub']}' opacity='0.3'/>"]
    for i, (ic, lab) in enumerate(tabs):
        cx = 160 + i * 320; on = i == active; col = C['ball'] if on else C['sub']
        out.append(text(cx, 848, ic, 36, extra="" if on else "opacity='0.6'"))
        out.append(text(cx, 884, lab, 20, col, weight="bold" if on else "normal"))
        if on:
            out.append(rr(cx - 60, 802, 120, 6, 3, col, glow=True))
        if lab == "Друзья":
            out.append(f"<circle cx='{cx + 30}' cy='824' r='14' fill='{C['lime']}'/>" + text(cx + 30, 831, "3", 18, INK))
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
            + text(800, 860, "тихий вход · аккаунт платформы", 18, C['sub'], weight="normal", extra="opacity='0.75'")
            + text(1560, 880, "v0.1", 18, C['sub'], anchor="end", weight="normal"))

def home_body():
    return (f"<rect x='120' y='757' width='640' height='4' fill='{C['cyan']}' opacity='0.5' filter='url(#glow)'/>"
            + f"<ellipse cx='430' cy='520' rx='300' ry='220' fill='{C['cyan']}' opacity='0.07' filter='url(#soft)'/>"
            + blob(430, 760, 140, C['cyan'], "happy", look=0.5)
            + ball(610, 300, 40)
            + rr(110, 140, 420, 64, 32, PANEL2, stroke=C['cyan'], sop=0.6)
            + text(140, 182, "🐸 Прыгун · прыжок +25%", 24, anchor="start") + text(500, 182, "✎", 26, C['cyan'])
            + rr(110, 222, 420, 60, 30, PANEL2, stroke=C['lime'], sop=0.5)
            + blob(146, 270, 18, C['lime'], "happy", glow=False) + blob(180, 270, 18, C['orange'], "happy", glow=False) + blob(214, 270, 18, C['buff'], "happy", glow=False)
            + text(250, 262, "3 друга в игре", 24, anchor="start") + text(500, 263, "›", 30, C['lime'])
            + rr(850, 170, 720, 560, 40, C['ball'], op=0.05, stroke=C['ball'], sw=2, sop=0.35)
            + btn(880, 200, 660, 220, "▶  ИГРАТЬ", size=76, sub="онлайн · на рейтинг")
            + btn(880, 445, 320, 110, "🤖 Против AI", size=32)
            + btn(1220, 445, 320, 110, "👥 С другом", size=32)
            + rr(880, 575, 660, 80, 26, PANEL2, stroke=C['cyan'], sw=2, sop=0.8)
            + text(910, 625, "🧊 Неделя льда · новый баф «Коньки»", 26, anchor="start") + text(1510, 627, "›", 36, C['cyan'], anchor="end")
            + text(1210, 703, "🟢 1 284 игрока онлайн · ~15 с до матча", 22, C['sub'], weight="normal"))

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
    out.append(btn(80, 770, 460, 100, "🎯 Испытания 12/40 ★", "secondary", 30))
    out.append(text(580, 830, "всё уже выбрано — можно сразу «Играть»", 22, C['sub'], anchor="start", weight="normal"))
    out.append(btn(1140, 770, 400, 100, "▶ ИГРАТЬ", size=44))
    return "".join(out)


# ---------- screens: matchmaking & lobby ----------
def scr_search():
    return (stars(1600, 900, 60, 9) + text(800, 150, "Ищем соперника…", 56)
            + text(800, 220, "0:12", 46, C['ball']) + text(800, 262, "ищем соперника твоего уровня: 1320–1520", 24, C['sub'], weight="normal")
            + text(800, 296, "диапазон расширяется каждые 5 с — матч найдётся всегда", 20, C['sub'], weight="normal", extra="opacity='0.8'")
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
            + text(800, 188, "ваши встречи: 3 : 1", 26, C['ball'])
            + blob(380, 620, 130, C['cyan'], "angry", look=1) + blob(1220, 620, 130, C['mag'], "smug", 1.15, 0.9, look=-1)
            + text(800, 470, "VS", 150, C['ball'], extra="filter='url(#glow)'")
            + text(380, 690, "Slimy_42", 40, C['cyan']) + text(380, 728, "🐸 Прыгун · 1420", 24, C['sub'], weight="normal")
            + text(1220, 690, "BlobKing", 40, C['mag']) + text(1220, 728, "🐷 Толстяк · 1395", 24, C['sub'], weight="normal")
            + text(330, 772, "+14", 30, C['lime']) + text(440, 772, "−17", 30, C['danger'])
            + text(1170, 772, "+17", 30, C['lime']) + text(1280, 772, "−14", 30, C['danger'])
            + rr(470, 810, 660, 64, 32, PANEL, stroke=C['sub'], sop=0.4)
            + text(800, 852, "Неоновый стадион · Classic · до 7", 24, weight="normal"))

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
            + hud_score(4, 3) + pause_btn() + touch() + iconbtn(1540, 58, 32, "😀")
            + marker(1470, 110, "7") + marker(130, 58, "1") + marker(985, 112, "2") + marker(1030, 160, "3")
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
    rating = ("1420 → 1434", "+14", C['lime']) if win else ("1420 → 1403", "−17", C['danger'])
    out.append(rr(880, 60, 660, 135, 24, PANEL, stroke=C['sub'], sop=0.4)
               + text(910, 96, "Рейтинг", 22, C['sub'], anchor="start", weight="normal")
               + text(910, 142, rating[0], 38, anchor="start") + text(1510, 140, rating[1], 50, rating[2], anchor="end")
               + text(910, 178, "соперник 1395 — ставка была +14 / −17", 20, C['sub'], anchor="start", weight="normal"))
    out.append(rr(880, 210, 660, 100, 24, PANEL, stroke=C['sub'], sop=0.4)
               + text(910, 262, "🪙 +100" if win else "🪙 +20", 36, anchor="start")
               + text(910, 295, "×2 — первая победа дня · задание ✓" if win else "задание «3 матча»: 2/3", 18, C['lime'] if win else C['sub'], anchor="start", weight="normal")
               + btn(1220, 225, 300, 70, "▶ ×2 за видео", "buff", 24))
    out.append(rr(880, 325, 660, 220, 24, PANEL, stroke=C['mag'], sw=3, sop=0.8)
               + rr(905, 350, 280, 170, 16, "#000", op=0.6)
               + f"<polygon points='930,480 1150,455 1155,495 925,510' fill='#3A4466' stroke='white' stroke-width='3'/>"
               + blob(1045, 518, 30, C['mag'], "dead", 1.8, 0.4, glow=False) + text(1045, 445, "▶", 50, "white", extra="opacity='0.85'")
               + text(1210, 390, "Лучший момент", 24, C['sub'], anchor="start", weight="normal")
               + text(1210, 430, "Потолок раздавил" if win else "Взрыв в упор", 28, anchor="start")
               + text(1210, 465, "BlobKing 💀" if win else "в свою сетку 🤦", 28, anchor="start")
               + btn(1210, 480, 310, 52, "📤 Поделиться", "accent", 24))
    if win:
        out.append(btn(880, 580, 310, 110, "↻ Реванш", "secondary", 32) + btn(1210, 580, 330, 110, "Дальше ›", size=38))
    else:
        out.append(btn(880, 580, 330, 110, "↻ Реванш", size=38) + btn(1230, 580, 310, 110, "Дальше ›", "secondary", 32))
        out.append(text(1210, 830, "💡 Толстяк плохо прыгает — бей высоко", 22, C['sub'], weight="normal"))
    out.append(btn(880, 710, 660, 76, "👋 BlobKing → в друзья · ваши встречи 3 : 1", "secondary", 24))
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
             ("🔒 Золото", C['buff'], 2), ("🔒 500", C['cyan'], 1), ("🔒 ▶", C['orange'], 1), ("🔒 100 побед", C['danger'], 2)]
    for i, (lab, col, st) in enumerate(items):
        x = 720 + (i % 4) * 205; y = 210 + (i // 4) * 255; on = i == 3
        out.append(rr(x, y, 185, 235, 22, PANEL2, stroke=C['ball'] if on else C['sub'], sw=4 if on else 2, sop=1 if on else 0.4))
        out.append(f"<polygon points='{x+52},{y+150} {x+132},{y+150} {x+102},{y+40}' fill='{col}' stroke='white' stroke-width='3' opacity='{0.55 if st else 1}'/>")
        out.append(f"<circle cx='{x+102}' cy='{y+40}' r='12' fill='white' opacity='{0.55 if st else 1}'/>")
        out.append(text(x + 92, y + 205, lab or "есть", 22, C['ball'] if lab == "✓" else (C['text'] if lab else C['sub']), weight="bold" if lab else "normal"))
    out.append(text(720, 740, "Только внешний вид — на игру не влияет", 22, C['sub'], anchor="start", weight="normal"))
    out.append(btn(720, 770, 420, 100, "🎖 Коллекция 34/120", "secondary", 28))
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
            + offer(565, 580, 470, 300, "Набор новичка", "3 скина · один раз", "199 ₽", blob(740, 680, 34, C['lime'], "happy", glow=False) + blob(800, 680, 40, C['orange'], "smug", glow=False) + blob(860, 680, 34, C['buff'], "happy", glow=False))
            + offer(1070, 580, 470, 300, "Бесплатно", "осталось 3 из 5", "▶ Видео → 🪙 +50", text(1305, 650, "🎁", 54), "buff"))

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
    out = [stars(1600, 900, 40, 71), topbar_back("Рейтинг"),
           chips(60, 128, ["Глобальный", "Неделя", "Друзья", "🇷🇺 Страна"], 0, size=24, h=60),
           btn(1140, 128, 400, 60, "🏅 Сезон 3 · ещё 41 д ›", "secondary", 24)]
    out += [lb_row(215 + i * 104, *r) for i, r in enumerate(rows)]
    out.append(lb_row(780, "#1 284", "Slimy_42 · ты", C['cyan'], "1 420", "🥈 Серебро II", me=True))
    return "".join(out)

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


# ---------- screens: account / linking ----------
def provider_row(x, y, w, icon, name, sub, state="linked"):
    """state: linked | add | primary"""
    h = 92
    stroke = C['lime'] if state == "linked" else (C['ball'] if state == "primary" else C['sub'])
    out = rr(x, y, w, h, 22, PANEL2, stroke=stroke, sop=0.7 if state != "add" else 0.35)
    out += text(x + 56, y + 58, icon, 36)
    out += text(x + 100, y + 48, name, 28, anchor="start")
    out += text(x + 100, y + 78, sub, 20, C['sub'], anchor="start", weight="normal")
    if state == "linked":
        out += text(x + w - 36, y + 58, "✓", 32, C['lime'], anchor="end")
    elif state == "add":
        out += rr(x + w - 160, y + 22, 130, 48, 24, C['cyan'], op=0.18, stroke=C['cyan'], sw=2, sop=0.8)
        out += text(x + w - 95, y + 54, "Добавить", 22, lighten(C['cyan'], 0.5))
    elif state == "primary":
        out += text(x + w - 36, y + 58, "→", 32, C['ball'], anchor="end")
    return out

def scr_home_guest():
    """Browser / unlinked guest: same home, soft non-blocking save strip."""
    banner = (rr(850, 740, 720, 54, 22, PANEL, stroke=C['ball'], sw=2, sop=0.65)
              + text(880, 776, "💾 Прогресс только здесь", 24, anchor="start")
              + rr(1220, 745, 320, 44, 22, C['ball'], op=0.95)
              + text(1380, 776, "Сохранить", 24, INK))
    return stars(1600, 900, 40, 5) + home_body() + topbar_profile() + navbar(0) + banner

def scr_save():
    """Soft save / first link — never a registration wall before Play."""
    body = (rr(280, 120, 1040, 680, 36, PANEL, stroke=C['sub'], sop=0.5)
            + text(800, 190, "Сохрани прогресс", 48)
            + text(800, 240, "Один аккаунт Goofy Ball — скины и рейтинг везде", 24, C['sub'], weight="normal")
            + iconbtn(1260, 175, 30, "✕")
            + btn(360, 290, 880, 100, "G  Продолжить с Google", size=34)
            + btn(360, 410, 880, 100, "🍎  Продолжить с Apple", "secondary", 34)
            + btn(360, 530, 420, 90, "🎮 Steam", "ghost", 28)
            + btn(800, 530, 440, 90, "📱 Код с телефона", "ghost", 28)
            + text(800, 660, "Браузер: Google — основной. Код — если уже играешь на телефоне.", 20, C['sub'], weight="normal")
            + text(800, 700, "Пароль не придумываем. Почту не спрашиваем.", 20, C['sub'], weight="normal")
            + btn(480, 740, 640, 70, "Позже — продолжить как гость", "ghost", 26))
    return (stars(1600, 900, 40, 5) + home_body() + topbar_profile() + navbar(0) + dim() + body)

def scr_account():
    """Settings → Аккаунт: linked providers + explain linking."""
    tabs = ["🎮 Управление", "🔊 Звук", "✨ Графика", "🌐 Язык", "👤 Аккаунт"]
    out = [stars(1600, 900, 40, 93), topbar_back("Настройки", money=False)]
    for i, t in enumerate(tabs):
        on = i == 4
        out.append(rr(60, 130 + i * 92, 340, 76, 22, C['cyan'] if on else PANEL2, op=0.9 if on else 1, stroke=None if on else C['sub'], sop=0.3))
        out.append(text(90, 178 + i * 92, t, 26, INK if on else C['text'], anchor="start", weight="bold" if on else "normal"))
    # profile card
    out.append(rr(440, 130, 1100, 150, 26, PANEL2, stroke=C['cyan'], sop=0.45))
    out.append(blob(520, 250, 48, C['cyan'], "happy", glow=False))
    out.append(text(590, 190, "Slimy_42", 34, anchor="start"))
    out.append(text(590, 230, "Goofy ID · gb_8f2a · создан через Google Play", 22, C['sub'], anchor="start", weight="normal"))
    out.append(text(590, 262, "Линковка = те же скины и рейтинг на другой платформе", 20, C['ball'], anchor="start", weight="normal"))
    # providers
    out.append(text(460, 330, "Способы входа", 24, C['sub'], anchor="start", weight="normal"))
    out.append(provider_row(440, 350, 1100, "G", "Google Play / Google", "основной · Android и браузер", "linked"))
    out.append(provider_row(440, 455, 1100, "🍎", "Apple", "не привязан · добавь для iPhone", "add"))
    out.append(provider_row(440, 560, 1100, "🎮", "Steam", "не привязан", "add"))
    out.append(provider_row(440, 665, 1100, "📱", "Код устройства", "разовый код · перенос в браузер", "add"))
    out.append(btn(440, 780, 520, 80, "+ Добавить вход", "secondary", 28))
    out.append(btn(1000, 780, 540, 80, "Уже есть аккаунт?", "ghost", 28))
    return "".join(out)

def scr_link():
    """Explain linking + pick a provider to attach."""
    out = [stars(1600, 900, 40, 94), topbar_back("Добавить вход", money=False),
           text(80, 160, "Что такое линковка?", 42, anchor="start"),
           rr(60, 190, 1480, 160, 26, PANEL, stroke=C['ball'], sw=2, sop=0.45),
           text(100, 250, "У тебя один аккаунт Goofy Ball. «Входы» (Google, Apple, Steam) — это ключи к нему.", 26, anchor="start", weight="normal"),
           text(100, 295, "Добавил Apple на Android-аккаунт → на iPhone открыл игру → тот же блоб, скины, рейтинг.", 26, anchor="start", weight="normal"),
           text(100, 335, "Ничего не копируем вручную. Не создаём второй профиль «с нуля».", 24, C['sub'], anchor="start", weight="normal"),
           text(80, 410, "Куда добавить вход?", 28, C['sub'], anchor="start", weight="normal"),
           provider_row(60, 430, 1480, "🍎", "Apple", "Sign in with Apple · 1 системный тап", "primary"),
           provider_row(60, 540, 1480, "🎮", "Steam", "если играешь с ПК", "primary"),
           provider_row(60, 650, 1480, "📱", "Показать код для браузера", "6 символов · ввести на сайте · 5 минут", "primary"),
           text(800, 800, "Старый вход не отключается. Можно отвязать позже в настройках.", 22, C['sub'], weight="normal"),
           btn(520, 820, 560, 70, "Отмена", "ghost", 28)]
    return "".join(out)

def scr_restore():
    """Cross-platform: I already play elsewhere."""
    body = (rr(280, 100, 1040, 720, 36, PANEL, stroke=C['sub'], sop=0.5)
            + iconbtn(1260, 155, 30, "✕")
            + text(800, 180, "Уже играл?", 48)
            + text(800, 235, "Войди тем же способом — прогресс подтянется", 24, C['sub'], weight="normal")
            + btn(360, 300, 880, 100, "G  Войти через Google", size=34)
            + btn(360, 420, 880, 100, "🍎  Войти через Apple", "secondary", 34)
            + btn(360, 540, 880, 100, "📱 Ввести код с другого устройства", "ghost", 30)
            + rr(360, 670, 880, 100, 22, PANEL2, stroke=C['sub'], sop=0.35)
            + text(800, 715, "Код:  ·  ·  ·  ·  ·  ·", 36, C['ball'])
            + text(800, 755, "Настройки → Аккаунт → «Показать код» на телефоне", 20, C['sub'], weight="normal"))
    return (stars(1600, 900, 40, 5) + home_body() + topbar_profile() + navbar(0) + dim() + body)

def scr_merge():
    """Two accounts met via linking — pick / combine without losing cosmetics."""
    def card(x, title, sub, items, col, pick=False):
        o = rr(x, 280, 460, 380, 28, PANEL2, stroke=C['ball'] if pick else col, sw=4 if pick else 2, sop=0.9)
        o += text(x + 230, 340, title, 30) + text(x + 230, 380, sub, 22, C['sub'], weight="normal")
        for i, line in enumerate(items):
            o += text(x + 40, 440 + i * 42, line, 24, anchor="start", weight="normal")
        if pick:
            o += rr(x + 80, 580, 300, 56, 28, C['ball'], op=0.95) + text(x + 230, 618, "Оставить этот", 24, INK)
        return o
    return (stars(1600, 900, 40, 95) + dim(0.55)
            + rr(200, 80, 1200, 760, 36, PANEL, stroke=C['orange'], sw=3, sop=0.7)
            + text(800, 160, "Нашли два прогресса", 44)
            + text(800, 215, "Ты привязал вход, у которого уже был другой аккаунт. Выбери основной —", 24, C['sub'], weight="normal")
            + text(800, 255, "косметику со второго можно забрать сюда (рейтинг — один, выше).", 24, C['sub'], weight="normal")
            + card(280, "Этот телефон", "Google Play · сейчас",
                   ["🪙 1 250 · 🥈 1420", "🐸 Прыгун + 3 скина", "создан сегодня"], C['cyan'], True)
            + card(860, "Старый аккаунт", "Apple · iPhone",
                   ["🪙 4 800 · 🏅 1880", "🐷 Толстяк + 12 скинов", "играешь 2 месяца"], C['mag'])
            + btn(360, 700, 400, 90, "Объединить косметику", "secondary", 26)
            + btn(840, 700, 400, 90, "Отмена", "ghost", 28))


# ---------- screens: retention (friends, habit, fresh content, mastery, collection) ----------
def mini_blobs(x, y, cols, r=18, step=34):
    return "".join(blob(x + i * step, y, r, c, "happy", glow=False) for i, c in enumerate(cols))

def friend_row(x, y, w, col, nick, status, scol, score, action, kind):
    return (rr(x, y, w, 92, 22, PANEL2, stroke=scol if scol == C['lime'] else None, sop=0.45)
            + blob(x + 56, y + 84, 32, col, "happy", glow=False)
            + text(x + 110, y + 42, nick, 30, anchor="start")
            + text(x + 110, y + 74, status, 20, scol, anchor="start", weight="normal")
            + text(x + w - 240, y + 56, score, 22, C['sub'], anchor="end", weight="normal")
            + btn(x + w - 210, y + 16, 190, 60, action, kind, 24))

def scr_friends():
    rows = [(C['lime'], "JellyBoi", "🟢 в меню", C['lime'], "ты 12 : 9", "Позвать", "primary"),
            (C['orange'], "Vasya_007", "🟢 в матче · 3 : 2", C['lime'], "ты 4 : 7", "После матча", "ghost"),
            (C['buff'], "GooGoo", "🟢 в меню", C['lime'], "ты 3 : 3", "Позвать", "primary"),
            (C['mag'], "Splat", "был 2 ч назад", C['sub'], "ты 1 : 0", "Вызов", "secondary"),
            (C['cyan'], "Mops", "был вчера", C['sub'], "—", "Вызов", "secondary")]
    out = [stars(1600, 900, 40, 101), topbar_back("Друзья"),
           chips(60, 128, ["Все 12", "🟢 В игре 3", "Запросы 2"], 0, size=24, h=60),
           btn(1060, 128, 480, 60, "🔗 Ссылка-приглашение", "secondary", 24)]
    out += [friend_row(60, 215 + i * 105, 940, *r) for i, r in enumerate(rows)]
    out.append(rr(1040, 215, 500, 512, 28, PANEL, stroke=C['ball'], sw=3, sop=0.6)
               + text(1290, 270, "Компания «Слизни»", 32)
               + text(1290, 305, "5 участников · 2 в игре", 22, C['sub'], weight="normal")
               + mini_blobs(1205, 390, [C['cyan'], C['lime'], C['orange'], C['buff'], C['mag']], 22, 42)
               + text(1080, 450, "Неделя: кто кого", 22, C['sub'], anchor="start", weight="normal"))
    for i, (n, sc) in enumerate((("👑 JellyBoi", "14 побед"), ("Slimy_42 · ты", "11 побед"), ("Vasya_007", "9 побед"))):
        out.append(text(1080, 495 + i * 42, n, 24, C['ball'] if i == 0 else C['text'], anchor="start")
                   + text(1500, 495 + i * 42, sc, 22, C['sub'], anchor="end", weight="normal"))
    out.append(btn(1080, 640, 420, 66, "Открыть компанию", "secondary", 26))
    out.append(text(60, 800, "«Позвать» = приглашение в комнату · друг увидит его на главной или поверх меню", 22, C['sub'], anchor="start", weight="normal"))
    out.append(text(60, 836, "Личный счёт «ты 12 : 9» — со всеми, с кем играл; соперничество держит лучше рейтинга", 22, C['sub'], anchor="start", weight="normal"))
    return "".join(out)

def scr_crew():
    members = [(C['cyan'], "ты", True), (C['lime'], "JellyBoi", True), (C['orange'], "Vasya", False), (C['buff'], "GooGoo", False), (C['mag'], "Splat", False)]
    out = [stars(1600, 900, 40, 102), topbar_back("Компания «Слизни»"),
           rr(60, 130, 720, 280, 28, PANEL, stroke=C['sub'], sop=0.4),
           f"<rect x='90' y='340' width='660' height='4' fill='{C['cyan']}' opacity='0.5' filter='url(#glow)'/>"]
    for i, (col, n, on) in enumerate(members):
        x = 150 + i * 130
        out.append(blob(x, 340, 44, col, "happy" if on else "smug", glow=on, opacity=1 if on else 0.55))
        out.append(text(x, 385, n, 22, C['text'] if on else C['sub'], weight="bold" if on else "normal"))
    out.append(text(90, 180, "5 участников · 2 в игре", 24, C['sub'], anchor="start", weight="normal"))
    out.append(rr(60, 430, 720, 340, 28, PANEL, stroke=C['ball'], sop=0.5)
               + text(90, 480, "Неделя: кто кого", 28, anchor="start") + text(750, 480, "ещё 3 д", 22, C['sub'], anchor="end", weight="normal"))
    table = [("👑", "JellyBoi", "14 – 6"), ("2", "Slimy_42 · ты", "11 – 8"), ("3", "Vasya_007", "9 – 9"), ("4", "GooGoo", "5 – 10")]
    for i, (r_, n, wl) in enumerate(table):
        y = 530 + i * 56
        out.append(text(110, y, r_, 26, C['ball'] if i == 0 else C['sub']) + text(160, y, n, 26, anchor="start", weight="bold" if i == 1 else "normal")
                   + text(750, y, wl, 26, C['text'], anchor="end"))
    out.append(text(90, 750, "лидер недели получает значок 👑 на блоб", 20, C['sub'], anchor="start", weight="normal"))
    out.append(btn(820, 130, 720, 190, "▶  Играть вместе", size=50, sub="комната компании · 2×2 / 3 команды"))
    out.append(btn(820, 340, 720, 120, "⚔ 2×2 против случайных", size=34, sub="ты + друг · на рейтинг"))
    out.append(btn(820, 480, 720, 96, "📣 Позвать всех", "secondary", 30))
    out.append(text(1180, 640, "Комната компании не исчезает:", 22, C['sub'], weight="normal"))
    out.append(text(1180, 674, "настройки, арена и счёт запоминаются", 22, C['sub'], weight="normal"))
    return "".join(out)

def scr_invite():
    return (stars(1600, 900, 40, 5) + home_body() + topbar_profile() + navbar(0) + dim(0.6)
            + rr(400, 190, 800, 470, 36, PANEL, stroke=C['lime'], sw=3, sop=0.8)
            + blob(560, 470, 90, C['lime'], "happy")
            + text(680, 330, "JellyBoi зовёт тебя", 40, anchor="start")
            + text(680, 375, "Комната · 2×2 · Неделя льда", 24, C['sub'], anchor="start", weight="normal")
            + text(680, 420, "в комнате уже 2 из 4", 22, C['lime'], anchor="start", weight="normal")
            + btn(460, 520, 420, 100, "Принять", size=36)
            + btn(900, 520, 240, 100, "Позже", "ghost", 30)
            + text(800, 720, "во время матча приглашение — тихая плашка сверху, не попап", 22, C['sub'], weight="normal"))

def quest_card(x, y, icon, title, prog, frac, reward, done=False):
    out = rr(x, y, 470, 340, 28, PANEL2, stroke=C['ball'] if done else C['sub'], sw=4 if done else 2, sop=0.9 if done else 0.4)
    out += text(x + 235, y + 100, icon, 70) + text(x + 235, y + 160, title, 26)
    out += bar(x + 40, y + 195, 390, 14, frac, C['lime'] if done else C['cyan']) + text(x + 235, y + 240, prog, 22, C['sub'], weight="normal")
    if done:
        out += btn(x + 60, y + 262, 350, 62, f"Забрать {reward}", size=26)
    else:
        out += text(x + 40, y + 300, reward, 26, anchor="start") + text(x + 430, y + 300, "↻ заменить", 20, C['sub'], anchor="end", weight="normal")
    return out

def scr_quests():
    return (stars(1600, 900, 40, 103) + topbar_back("Задания")
            + rr(60, 130, 1480, 130, 28, PANEL, stroke=C['lime'], sw=3, sop=0.7)
            + text(100, 185, "🏆 Первая победа дня", 36, anchor="start")
            + text(100, 228, "×2 монеты за первую победу каждый день · обновится в 00:00", 22, C['sub'], anchor="start", weight="normal")
            + rr(1250, 165, 250, 60, 30, C['ball'], op=0.15, stroke=C['ball'], sw=2, sop=0.8) + text(1375, 205, "ещё не взята", 24, C['ball'])
            + quest_card(60, 290, "🎮", "Сыграй 3 матча", "1 / 3", 0.33, "🪙 +30")
            + quest_card(565, 290, "🔨", "Раздави потолком", "0 / 1", 0.0, "🪙 +60")
            + quest_card(1070, 290, "🍄", "Победи гигантом", "1 / 1 ✓", 1.0, "🪙 +50", done=True)
            + rr(60, 660, 1040, 110, 26, PANEL, stroke=C['cyan'], sw=2, sop=0.7)
            + text(100, 705, "Задание недели: 15 побед на льду 🧊", 28, anchor="start")
            + bar(100, 728, 660, 14, 0.6, C['cyan']) + text(790, 745, "9 / 15", 22, C['sub'], anchor="start", weight="normal")
            + text(1070, 745, "🧢 «Сосулька»", 26, anchor="end")
            + btn(1140, 660, 400, 110, "▶ ИГРАТЬ", size=40)
            + text(60, 830, "Новые задания через 6 ч · пропуск дней ничего не сжигает · задания учат бафам", 22, C['sub'], anchor="start", weight="normal"))

def scr_weekly():
    flakes = "".join(text(100 + (i * 137) % 680, 200 + (i * 83) % 300, "❄", 22 + i % 3 * 8, "white", weight="normal", extra="opacity='0.35'") for i in range(12))
    return (stars(1600, 900, 40, 104) + topbar_back("Неделя льда")
            + rr(60, 130, 760, 640, 30, C['cyan'], op=0.07, stroke=C['cyan'], sw=3, sop=0.7) + flakes
            + text(440, 230, "🧊 НЕДЕЛЯ ЛЬДА", 60, C['cyan'], extra="filter='url(#glow)'")
            + rr(330, 260, 220, 50, 25, PANEL, stroke=C['cyan'], sop=0.7) + text(440, 294, "ещё 3 д 4 ч", 24)
            + f"<rect x='100' y='680' width='680' height='10' rx='5' fill='{lighten(C['cyan'], 0.6)}' opacity='0.8' filter='url(#glow)'/>"
            + f"<rect x='436' y='540' width='8' height='140' rx='4' fill='{lighten(C['cyan'], 0.6)}' filter='url(#glow)'/>"
            + blob(250, 680, 60, C['cyan'], "happy", 1.25, 0.8, look=1)
            + f"<path d='M150,640 l-50,0 M160,665 l-70,0 M150,615 l-40,0' stroke='white' stroke-width='5' opacity='0.4' stroke-linecap='round'/>"
            + blob(620, 680, 60, C['mag'], "scared", 0.85, 1.1, look=-1) + ball(440, 420, 30, trail=(-18, 14))
            + text(880, 200, "Что меняется", 28, C['sub'], anchor="start", weight="normal")
            + text(880, 260, "❄  Ледяной пол во всех онлайн-матчах", 28, anchor="start")
            + text(880, 320, "🛼  Новый баф «Коньки» — рывок по льду", 28, anchor="start")
            + text(880, 380, "🎯  Испытание недели: 3 гола с отскока", 28, anchor="start")
            + text(880, 440, "🧢  Шапка «Сосулька» за задание недели", 28, anchor="start")
            + rr(860, 480, 680, 76, 22, PANEL, stroke=C['lime'], sw=2, sop=0.7)
            + text(1200, 527, "Очередь та же — неделя не делит игроков", 24, C['lime'])
            + btn(860, 580, 680, 130, "▶  ИГРАТЬ", size=50, sub="онлайн · неделя льда")
            + rr(860, 730, 680, 70, 22, PANEL, stroke=C['sub'], sop=0.5, dash="10 8")
            + text(1200, 775, "Скоро: 🌙 Неделя луны · низкая гравитация", 24, C['sub'], weight="normal")
            + text(60, 830, "Против AI и в комнате неделю можно выбрать отдельно — как пресет «Ice»", 22, C['sub'], anchor="start", weight="normal"))

def scr_news():
    def card(x, label, art, title, desc):
        return (rr(x, 200, 480, 380, 28, PANEL2, stroke=C['buff'], sw=3, sop=0.7) + text(x + 240, 245, label, 22, C['buff'])
                + art + text(x + 240, 500, title, 36) + text(x + 240, 545, desc, 22, C['sub'], weight="normal"))
    skates = (blob(540, 430, 70, C['cyan'], "happy", look=1)
              + "<rect x='470' y='432' width='60' height='22' rx='11' fill='#F2F2F2' stroke='#03B8FF' stroke-width='3'/>"
              + "<rect x='552' y='432' width='60' height='22' rx='11' fill='#F2F2F2' stroke='#03B8FF' stroke-width='3'/>")
    magnet = blob(1060, 450, 72, C['orange'], "smug", look=-1) + text(1150, 330, "🧲", 56) + ball(980, 320, 24)
    return (stars(1600, 900, 40, 5) + home_body() + topbar_profile() + navbar(0) + dim(0.75)
            + rr(260, 90, 1080, 730, 36, PANEL, stroke=C['buff'], sw=3, sop=0.8)
            + text(800, 160, "Что нового · обновление 0.4", 44)
            + card(300, "НОВЫЙ БАФ", skates, "🛼 Коньки", "рывок по льду, сносит соперника")
            + card(820, "НОВЫЙ ПЕРСОНАЖ", magnet, "🧲 Магнитик", "мяч чуть тянется к нему")
            + text(800, 630, "+ арена «Каток» · баланс: Толстяк прыгает чуть выше", 24, C['sub'], weight="normal")
            + btn(300, 680, 580, 100, "▶ Попробовать против AI", size=32)
            + btn(900, 680, 400, 100, "Ок", "ghost", 32)
            + text(800, 860, "показывается один раз после обновления · новое каждые 2–3 недели", 20, C['sub'], weight="normal"))

def scr_season():
    ranks = [("🥉", "Бронза", "0+", "🎖 рамка", "done"), ("🥈", "Серебро", "1200+", "🧢 кепка", "here"),
             ("🥇", "Золото", "1500+", "✨ след", "lock"), ("🏅", "Платина", "1800+", "🎆 победа", "lock"),
             ("💎", "Алмаз", "2100+", "🐉 скин", "lock"), ("👑", "Легенда", "топ-100", "👑 корона", "lock")]
    out = [stars(1600, 900, 40, 105), topbar_back("Сезон 3"),
           text(60, 170, "ещё 41 день · в начале сезона мягкий сброс: рейтинг сжимается к середине", 24, C['sub'], anchor="start", weight="normal")]
    for i, (ic, name, thr, rew, st) in enumerate(ranks):
        x = 60 + i * 248; here = st == "here"
        out.append(rr(x, 210, 228, 400, 26, PANEL2, stroke=C['ball'] if here else (C['lime'] if st == "done" else C['sub']),
                      sw=4 if here else 2, sop=1 if here else 0.45, glow=here))
        out.append(text(x + 114, 300, ic, 70, extra="" if st != "lock" else "opacity='0.55'"))
        out.append(text(x + 114, 360, name, 30) + text(x + 114, 395, thr, 22, C['sub'], weight="normal"))
        out.append(rr(x + 24, 425, 180, 90, 18, "#000", op=0.3) + text(x + 114, 480, rew, 24))
        out.append(text(x + 114, 575, {"done": "✓ получено", "here": "ты здесь · 1420", "lock": "🔒"}[st], 22,
                        {"done": C['lime'], "here": C['ball'], "lock": C['sub']}[st], weight="bold" if here else "normal"))
    out.append(text(60, 670, "До Золота: 80 очков", 28, anchor="start") + bar(60, 690, 1000, 16, 0.6, C['ball']))
    out.append(text(60, 760, "Награда — за итоговый ранг сезона. Без пасса и покупок.", 22, C['sub'], anchor="start", weight="normal"))
    out.append(text(60, 795, "Полученное остаётся навсегда и показывает, когда ты играл.", 22, C['sub'], anchor="start", weight="normal"))
    out.append(btn(1140, 660, 400, 110, "▶ ИГРАТЬ", size=40))
    return "".join(out)

def scr_profile():
    pts = [(700, 330), (780, 318), (860, 335), (940, 300), (1020, 296), (1100, 270), (1180, 282), (1260, 240), (1340, 226), (1420, 205), (1500, 190)]
    poly = " ".join(f"{x},{y}" for x, y in pts)
    stats = [("Матчей", "214"), ("Побед", "56%"), ("Серия", "9 🔥"), ("Потолком", "×37 🔨"), ("Взрывов", "×52 💥"), ("Любимый", "🍄 Гигант")]
    out = [stars(1600, 900, 40, 106), topbar_back("Профиль"),
           rr(60, 130, 560, 380, 28, PANEL, stroke=C['cyan'], sop=0.5),
           f"<ellipse cx='340' cy='300' rx='200' ry='120' fill='{C['cyan']}' opacity='0.08' filter='url(#soft)'/>",
           blob(340, 370, 100, C['cyan'], "smug", look=0.4),
           text(340, 430, "Slimy_42", 40), text(340, 470, "🥈 Серебро II · 1420", 24, C['sub'], weight="normal"),
           text(60, 560, "Мастерство персонажей", 24, C['sub'], anchor="start", weight="normal")]
    for i, (n, lv, f) in enumerate((("🐸 Прыгун", "ур. 7", 0.7), ("🐷 Толстяк", "ур. 3", 0.3), ("🍯 Липкий", "ур. 1", 0.1))):
        y = 605 + i * 78
        out.append(text(60, y, n, 26, anchor="start") + text(620, y, lv, 24, C['ball'], anchor="end") + bar(60, y + 16, 560, 12, f, C['ball']))
    out.append(rr(660, 130, 880, 250, 26, PANEL, stroke=C['sub'], sop=0.4)
               + text(690, 175, "Рейтинг · 30 дней", 24, C['sub'], anchor="start", weight="normal")
               + text(1510, 175, "1310 → 1420", 26, C['lime'], anchor="end")
               + f"<polyline points='{poly}' fill='none' stroke='{C['cyan']}' stroke-width='5' stroke-linejoin='round' filter='url(#glow)'/>"
               + f"<circle cx='1500' cy='190' r='9' fill='{C['ball']}'/>")
    for i, (lab, val) in enumerate(stats):
        x = 660 + (i % 3) * 300; y = 400 + (i // 3) * 125
        out.append(rr(x, y, 280, 110, 22, PANEL2, stroke=C['sub'], sop=0.35)
                   + text(x + 140, y + 48, val, 34) + text(x + 140, y + 88, lab, 20, C['sub'], weight="normal"))
    out.append(btn(660, 670, 420, 100, "🎯 Испытания 12/40 ★", "secondary", 28))
    out.append(btn(1120, 670, 420, 100, "🎖 Коллекция 34/120", "secondary", 28))
    out.append(text(1100, 830, "Цифры, которыми хочется хвастаться, — повод для клипа и реванша", 22, C['sub'], weight="normal"))
    return "".join(out)

def scr_trials():
    cards = [("🏐", "Подача в угол", "★★★", "done"), ("🦘", "Удар в прыжке", "★★☆", "done"), ("🌀", "Гол через портал", "★☆☆", "open"),
             ("🙅", "Победи без прыжков", "☆☆☆", "open"), ("🔨", "Потолок на голову", "☆☆☆", "open"), ("🧊", "3 гола с отскока", "☆☆☆", "week"),
             ("🧲", "Магнит: 3 паса", "", "lock"), ("💥", "Взрыв-сейв", "", "lock")]
    out = [stars(1600, 900, 40, 107), topbar_back("Испытания"),
           chips(60, 128, ["Механика", "Бафы", "Неделя 🧊"], 0, size=24, h=60),
           text(1540, 172, "★ 12 / 40", 34, C['ball'], anchor="end")]
    for i, (ic, t, st, state) in enumerate(cards):
        x = 60 + (i % 4) * 378; y = 215 + (i // 4) * 285
        lock = state == "lock"
        out.append(rr(x, y, 345, 265, 26, PANEL2, stroke=C['cyan'] if state == "week" else (C['ball'] if state == "open" and i == 2 else C['sub']),
                      sw=3, sop=0.8 if state != "lock" else 0.3))
        out.append(text(x + 172, y + 105, ic, 68, extra="opacity='0.4'" if lock else ""))
        out.append(text(x + 172, y + 165, t, 26, C['sub'] if lock else C['text']))
        if lock:
            out.append(text(x + 172, y + 220, "🔒 открой за 15 ★", 22, C['sub'], weight="normal"))
        else:
            got = st.count("★")
            out.append("".join(text(x + 132 + j * 40, y + 222, "★", 36, C['ball'] if j < got else PANEL, extra="" if j < got else f"stroke='{C['sub']}' stroke-width='2'") for j in range(3)))
        if state == "week":
            out.append(rr(x + 220, y + 16, 110, 36, 18, C['cyan'], op=0.9) + text(x + 275, y + 41, "неделя", 18, INK))
    out.append(text(60, 830, "30–60 секунд, офлайн · учат приёмам, которые работают в рейтинге · звёзды открывают новые", 22, C['sub'], anchor="start", weight="normal"))
    return "".join(out)

def scr_collection():
    cx, cy, r, frac = 330, 360, 150, 34 / 120
    a = -math.pi / 2 + frac * 2 * math.pi
    arc = f"M{cx},{cy - r} A{r},{r} 0 {1 if frac > 0.5 else 0} 1 {cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}"
    cats = [("🧢", "Шапки", 12, 40), ("🫧", "Скины", 8, 30), ("🏐", "Мячи", 3, 15), ("🎆", "Эффекты победы", 2, 10), ("✨", "Следы", 5, 15), ("😎", "Эмоции", 4, 10)]
    out = [stars(1600, 900, 40, 108), topbar_back("Коллекция"),
           f"<circle cx='{cx}' cy='{cy}' r='{r}' fill='none' stroke='{PANEL2}' stroke-width='28'/>",
           f"<path d='{arc}' fill='none' stroke='{C['ball']}' stroke-width='28' stroke-linecap='round' filter='url(#glow)'/>",
           text(cx, cy + 10, "34/120", 58), text(cx, cy + 50, "собрано", 24, C['sub'], weight="normal"),
           text(cx, 570, "видно в матче и в клипах", 22, C['sub'], weight="normal")]
    for i, (ic, n, have, tot) in enumerate(cats):
        y = 140 + i * 92
        out.append(rr(620, y, 920, 78, 20, PANEL2, stroke=C['sub'], sop=0.3)
                   + text(670, y + 52, ic, 36) + text(720, y + 50, n, 28, anchor="start")
                   + bar(1060, y + 33, 330, 12, have / tot, C['ball']) + text(1510, y + 50, f"{have}/{tot}", 24, C['ball'], anchor="end"))
    out.append(text(60, 700, "Только за достижения — не купить", 26, C['ball'], anchor="start"))
    ach = [("👑 Корона", "100 побед", 0.56, "56/100"), ("🌋 След лавы", "раздави 50 раз", 0.74, "37/50"), ("🤡 Эмоция «Клоун»", "10 взрывов-сейвов", 0.2, "2/10")]
    for i, (n, how, f, p) in enumerate(ach):
        x = 60 + i * 500
        out.append(rr(x, 720, 470, 140, 22, PANEL, stroke=C['ball'], sw=2, sop=0.5)
                   + text(x + 30, 765, n, 28, anchor="start") + text(x + 440, 765, p, 22, C['sub'], anchor="end", weight="normal")
                   + text(x + 30, 800, how, 22, C['sub'], anchor="start", weight="normal") + bar(x + 30, 825, 410, 12, f, C['lime']))
    return "".join(out)

def scr_emote():
    emos = ["😂", "😎", "🤡", "🙏", "😱"]
    bar_ = rr(450, 770, 700, 104, 52, PANEL, stroke=C['ball'], sw=2, sop=0.6)
    for i, e in enumerate(emos):
        x = 530 + i * 135
        bar_ += (f"<circle cx='{x}' cy='822' r='42' fill='{C['ball'] if i == 1 else PANEL2}' fill-opacity='{0.25 if i == 1 else 1}' "
                 f"stroke='{C['ball'] if i == 1 else C['sub']}' stroke-width='3' stroke-opacity='0.8'/>" + text(x, 838, e, 46))
    def bubble(x, y, e):
        return (rr(x - 55, y - 100, 110, 96, 30, "white", op=0.95) + f"<polygon points='{x-14},{y-6} {x+14},{y-6} {x},{y+14}' fill='white' opacity='0.95'/>"
                + text(x, y - 34, e, 56))
    return (arena(seed=15) + blob(500, 760, 66, C['cyan'], "smug", look=1) + blob(1150, 760, 66, C['mag'], "scared", look=-1)
            + bubble(500, 610, "😎") + bubble(1150, 610, "😱") + ball(800, 300, 30)
            + hud_score(5, 3) + pause_btn()
            + rr(560, 130, 480, 56, 28, PANEL, stroke=C['sub'], sop=0.5) + text(800, 168, "между розыгрышами · 2 с", 24, C['sub'], weight="normal")
            + bar_)


# ---------- navigation map ----------
def sheet_flow():
    """Interactive flow map: nodes carry data-t=SCREENS key for prototype clicks."""
    W, H = 2000, 2240
    NW, NH = 248, 88
    out = [stars(W, H, 60), text(W / 2, 56, "UI — карта экранов", 44),
           text(W / 2, 94, "жёлтый — матч · циан — аккаунт · клик по окну открывает экран в прототипе", 22, C['sub'], weight="normal"),
           "<defs>"
           + "".join(f"<marker id='ar{k}' viewBox='0 0 10 10' refX='9' refY='5' markerWidth='7' markerHeight='7' orient='auto-start-reverse'><path d='M0,0 L10,5 L0,10 z' fill='{c}'/></marker>"
                     for k, c in (("Y", C['ball']), ("S", C['sub']), ("C", C['cyan']), ("M", C['mag'])))
           + "</defs>"]
    # id → (cx, cy, title, subtitle, stroke, screens_key|None)
    nodes = {
        "splash": (160, 280, "Загрузка", "тихий вход", C['sub'], "splash"),
        "tutorial": (160, 460, "Обучение", "только 1-й раз", C['sub'], "tutorial"),
        "home": (480, 280, "Главная", "Play / Apple / Steam", C['ball'], "home"),
        "home_guest": (480, 460, "Главная · гость", "браузер", C['cyan'], "home_guest"),
        "save": (760, 460, "Сохранить", "Google / Apple / код", C['cyan'], "save"),
        "account": (1040, 460, "Аккаунт", "ключи · Goofy ID", C['cyan'], "account"),
        "link": (1320, 460, "Линковка", "добавить вход", C['cyan'], "link"),
        "restore": (1040, 620, "Уже играл?", "войти / код", C['cyan'], "restore"),
        "merge": (1320, 620, "Два прогресса", "редко · merge", C['orange'], "merge"),
        "friend": (760, 200, "С другом", "код · ссылка", C['ball'], "friend"),
        "ai": (760, 280, "Против AI", "всё по умолчанию", C['ball'], "ai"),
        "search": (760, 360, "Поиск", "1 тап · рейтинг", C['ball'], "search"),
        "room": (1040, 200, "Комната", "после «с другом»", C['ball'], "room"),
        "vs": (1040, 300, "VS", "3 с · ставка", C['ball'], "vs"),
        "hud": (1320, 300, "Матч HUD", "счёт · 2 кнопки", C['ball'], "hud"),
        "pause": (1320, 200, "Пауза", "меню в онлайне", C['sub'], "pause"),
        "point": (1600, 220, "Очко", "слоумо · клип", C['sub'], "point"),
        "reconnect": (1600, 320, "Связь", "соперник оффлайн", C['orange'], "reconnect"),
        "multi": (1600, 420, "3 команды", "жизни зон", C['sub'], "multi"),
        "win": (1840, 220, "Победа", "реванш · дальше", C['ball'], "win"),
        "lose": (1840, 330, "Поражение", "реванш главнее", C['danger'], "lose"),
        "share": (1840, 440, "Клип", "поделиться", C['mag'], "share"),
        "rankup": (1840, 550, "Новый ранг", "попап · редко", C['sub'], "rankup"),
        "blob": (280, 820, "Блоб", "скины", C['cyan'], "blob"),
        "shop": (560, 820, "Магазин", "косметика", C['cyan'], "shop"),
        "leader": (840, 820, "Рейтинг", "лидерборд", C['cyan'], "leader"),
        "settings": (1120, 820, "Настройки", "управление…", C['cyan'], "settings"),
        "friends": (200, 1140, "Друзья", "кто в игре · позвать", C['lime'], "friends"),
        "crew": (200, 1250, "Компания", "кто кого за неделю", C['lime'], "crew"),
        "invite": (200, 1360, "Приглашение", "так видит друг", C['lime'], "invite"),
        "quests": (580, 1140, "Задания дня", "×2 первая победа", C['ball'], "quests"),
        "weekly": (960, 1140, "Неделя льда", "во всех матчах", C['cyan'], "weekly"),
        "news": (960, 1250, "Что нового", "после обновления", C['buff'], "news"),
        "season": (960, 1360, "Сезон", "награда за ранг", C['ball'], "season"),
        "profile": (1340, 1140, "Профиль", "статистика", C['cyan'], "profile"),
        "trials": (1340, 1250, "Испытания", "★ приёмы", C['cyan'], "trials"),
        "collection": (1720, 1140, "Коллекция", "34/120", C['mag'], "collection"),
        "emote": (1720, 1250, "Эмоции", "между розыгрышами", C['mag'], "emote"),
    }
    colmap = {"Y": C['ball'], "S": C['sub'], "C": C['cyan'], "M": C['mag']}

    def edge(a, b, kind="S", dash=False, both=False, side="h", label=None):
        ax, ay = nodes[a][:2]; bx, by = nodes[b][:2]
        if side == "h":
            x1, y1, x2, y2 = ax + NW / 2, ay, bx - NW / 2 - 4, by
            mx = (x1 + x2) / 2
            d = f"M{x1},{y1} C{mx},{y1} {mx},{y2} {x2},{y2}"
            lx, ly = (x1 + x2) / 2, (y1 + y2) / 2 - 14
        elif side == "v":
            sgn = 1 if by > ay else -1
            d = f"M{ax},{ay + sgn * NH / 2 + (sgn * 4 if both else 0)} L{bx},{by - sgn * NH / 2 - sgn * 4}"
            lx, ly = ax + 8, (ay + by) / 2
        else:  # bend down then across
            mid = max(ay, by) + 70
            d = f"M{ax},{ay + NH / 2} L{ax},{mid} L{bx},{mid} L{bx},{by + NH / 2}"
            lx, ly = (ax + bx) / 2, mid - 14
        c = colmap[kind]
        sw = 5 if kind == "Y" else 3
        s = (f"<path d='{d}' stroke='{c}' stroke-width='{sw}' fill='none' opacity='0.9'"
             + (" stroke-dasharray='10 8'" if dash else "") + f" marker-end='url(#ar{kind})'"
             + (f" marker-start='url(#ar{kind})'" if both else "") + "/>")
        if label:
            s += text(lx, ly, label, 16, c, weight="normal")
        return s

    # --- auth variants ---
    out.append(rr(40, 150, 1560, 560, 28, PANEL, op=0.35, stroke=C['cyan'], sw=2, sop=0.35))
    out.append(text(60, 190, "ВАРИАНТЫ ВХОДА И АККАУНТА", 22, C['cyan'], anchor="start"))
    out.append(text(60, 222, "Play / Apple / Steam → сразу Главная · браузер → гость → сохранить по желанию · линковка = ещё ключ", 18, C['sub'], anchor="start", weight="normal"))

    out += [
        edge("splash", "home", "S", label="магазин"),
        edge("splash", "home_guest", "C", dash=True, side="v", label="браузер"),
        edge("splash", "tutorial", "S", dash=True, side="v", label="1-й раз"),
        edge("tutorial", "home", "S"),
        edge("home_guest", "save", "C"),
        edge("save", "account", "C"),
        edge("account", "link", "C"),
        edge("account", "restore", "C", side="v"),
        edge("link", "merge", "S", dash=True, side="v", label="конфликт"),
        edge("restore", "account", "C", dash=True),
        edge("home_guest", "search", "Y", dash=True, label="играть без сохранения"),
    ]

    # --- match path ---
    out.append(rr(620, 150, 1340, 560, 28, PANEL, op=0.2, stroke=C['ball'], sw=2, sop=0.35))
    out.append(text(640, 190, "МАТЧ", 22, C['ball'], anchor="start"))
    out += [
        edge("home", "search", "Y", label="1 тап"),
        edge("home", "ai", "Y"),
        edge("home", "friend", "Y"),
        edge("friend", "room", "S"),
        edge("ai", "vs", "S"),
        edge("search", "vs", "Y"),
        edge("room", "vs", "S"),
        edge("vs", "hud", "Y"),
        edge("hud", "pause", "S", both=True, side="v"),
        edge("hud", "point", "S"),
        edge("hud", "reconnect", "S", dash=True),
        edge("point", "win", "Y"),
        edge("point", "lose", "S", dash=True),
        edge("reconnect", "win", "S", dash=True),
        edge("win", "share", "M", side="v"),
        edge("win", "rankup", "S", dash=True, side="v"),
        edge("lose", "share", "M", dash=True),
    ]

    # --- meta tabs ---
    out.append(rr(40, 740, 1400, 200, 28, PANEL, op=0.3, stroke=C['sub'], sw=2, sop=0.4))
    out.append(text(60, 780, "МЕНЮ С ГЛАВНОЙ", 22, C['sub'], anchor="start"))
    out.append(f"<path d='M480,{280 + NH/2} L480,740' stroke='{C['sub']}' stroke-width='3' fill='none' stroke-dasharray='8 8'/>")
    out.append(f"<path d='M280,740 L1120,740' stroke='{C['sub']}' stroke-width='3' fill='none'/>")
    # settings → account is the same screen cluster; show as label only (avoid crossing edge)
    out.append(text(1280, 820, "→ Аккаунт", 18, C['cyan'], anchor="start", weight="normal"))

    # --- retention ---
    out.append(rr(40, 980, 1920, 460, 28, PANEL, op=0.3, stroke=C['lime'], sw=2, sop=0.45))
    out.append(text(60, 1020, "УДЕРЖАНИЕ — ЗАЧЕМ ВОЗВРАЩАТЬСЯ", 22, C['lime'], anchor="start"))
    pillars = [(200, "ДРУЗЬЯ", "вкладка · «3 друга в игре» · «в друзья»"), (580, "ПРИВЫЧКА", "чип «Задания» в шапке · итоги"),
               (960, "СВЕЖИЙ КОНТЕНТ", "полоса в блоке ИГРАТЬ · рейтинг"), (1340, "МАСТЕРСТВО", "профиль · «Против AI» · VS"),
               (1720, "КОЛЛЕКЦИЯ", "Блоб · профиль · кнопка 😀 в матче")]
    for x, t, s_ in pillars:
        out.append(text(x, 1046, t, 20, C['ball']) + text(x, 1068, "вход: " + s_, 15, C['sub'], weight="normal"))
    out += [edge("friends", "crew", "S", side="v"), edge("crew", "invite", "S", side="v"),
            edge("news", "weekly", "S", side="v"), edge("profile", "trials", "S", side="v"),
            edge("quests", "weekly", "S", label="задание недели"), edge("profile", "collection", "M", label="коллекция")]

    # draw nodes (clickable groups)
    for k, (x, y, t, s, col, target) in nodes.items():
        big = k in ("home", "search", "hud")
        hit = rr(x - NW / 2, y - NH / 2, NW, NH, 22, PANEL, stroke=col, sw=5 if big else 3, sop=0.95, glow=big)
        body = hit + text(x, y - (4 if s else -8), t, 26)
        if s:
            body += text(x, y + 28, s, 17, C['sub'], weight="normal")
        if target:
            # <a> is a reliable SVG hit-target; data-t drives the prototype router
            out.append(f"<a class='map-node' data-t='{target}' href='#{target}' role='link' tabindex='0'>"
                       f"<title>{t} — открыть</title>{body}</a>")
        else:
            out.append(body)

    # legend + principles
    out.append(rr(1480, 740, 480, 200, 24, PANEL, stroke=C['sub'], sop=0.4))
    out.append(text(1520, 785, "ЛЕГЕНДА", 22, C['ball'], anchor="start"))
    legend = [("жёлтый", C['ball'], "главный путь к матчу"),
              ("циан", C['cyan'], "аккаунт / линковка"),
              ("пунктир", C['sub'], "опционально / редко"),
              ("клик", C['lime'], "по окну → этот экран")]
    for i, (lab, col, desc) in enumerate(legend):
        out.append(f"<circle cx='1540' cy='{820 + i * 28}' r='8' fill='{col}'/>"
                   + text(1565, 826 + i * 28, f"{lab}: {desc}", 18, anchor="start", weight="normal"))

    pr = ["1. «ИГРАТЬ» = онлайн на рейтинг, 1 тап.  2. Одна очередь.  3. Дефолты везде.  4. Жёлтые кнопки запуска вместе.",
          "5. Главное действие справа снизу.  6. В матче минимум UI.  7. Цвет = смысл.  8. Иконка + 1–2 слова.",
          "9. Только косметика.  10. Аккаунт тихо по платформе; линковка добровольно, без стен регистрации.",
          "11. Удержание: друзья важнее рейтинга · задания без энергии и штрафов · новый баф каждые 2–3 недели · неделя не делит очередь."]
    out.append(rr(40, 1480, 1920, 192, 28, PANEL, stroke=C['ball'], sw=2, sop=0.45))
    out.append(text(70, 1530, "ПРИНЦИПЫ", 24, C['ball'], anchor="start"))
    for i, p in enumerate(pr):
        out.append(text(70, 1570 + i * 32, p, 20, anchor="start", weight="normal"))

    # variants callouts
    out.append(rr(40, 1712, 1920, 500, 28, PANEL, stroke=C['cyan'], sw=2, sop=0.4))
    out.append(text(70, 1762, "ЧТО МОЖЕТ ПРОИЗОЙТИ", 26, C['cyan'], anchor="start"))
    variants = [
        ("A. Магазин (Android / iOS / Steam)", "Загрузка → тихий вход платформы → Главная → ИГРАТЬ. Аккаунт уже есть, форм нет."),
        ("B. Первый запуск", "Загрузка → Обучение (матч с AI) → Главная. Можно пропустить."),
        ("C. Браузер, новый игрок", "Загрузка → Главная·гость → ИГРАТЬ сразу. Плашка «Сохранить» не блокирует матч."),
        ("D. Сохранить прогресс", "Гость → Сохранить → Google / Apple / Steam / код с телефона → Аккаунт с ключом."),
        ("E. Линковка на другую платформу", "Аккаунт → Добавить вход → Apple/Steam/код. Тот же Goofy ID, новый ключ."),
        ("F. Уже играл на другом устройстве", "Уже играл? → войти тем же ключом или ввести код → прогресс подтягивается."),
        ("G. Конфликт двух аккаунтов", "Привязали ключ, у которого уже был другой Goofy ID → Два прогресса (выбор / merge косметики)."),
        ("H. После матча", "Победа или поражение → Реванш (VS) / Дальше (Главная) / Клип / редкий Новый ранг."),
        ("I. Играть с друзьями", "Друзья → Позвать → Комната; друг видит Приглашение → Принять. Компания — постоянная комната."),
        ("J. Зачем зайти сегодня", "Задания дня и ×2 первая победа · Неделя льда · «Что нового» · Сезон с наградой."),
    ]
    for i, (title, desc) in enumerate(variants):
        col = i % 2
        row = i // 2
        x = 70 + col * 960
        y = 1802 + row * 80
        out.append(text(x, y, title, 22, C['ball'] if i < 3 else C['text'], anchor="start"))
        out.append(text(x, y + 32, desc, 18, C['sub'], anchor="start", weight="normal"))

    return save("ui-flow", svg(W, H, "".join(out))), W, H


# ---------- screen registry: title, render fn, notes, hotspots (x, y, w, h, target, label), auto (ms, target) ----------
BACK = (42, 26, 68, 68, "back", "← Назад")
GEAR = (1508, 24, 64, 64, "settings", "⚙ Настройки")
FULL = lambda target, label: (0, 0, 1600, 900, target, label)

SCREENS = {
    "splash": ("Загрузка", scr_splash, ["Тихий вход: Play Games / Game Center / Steam / гость в браузере.", "Игрок не выбирает «как зарегистрироваться» — аккаунт создаётся сам.", "Первый запуск → обучение. Без экранов «введите ник» и стен с паролем."],
               [FULL("tutorial", "Тап → обучение")], (2200, "tutorial")),
    "home": ("Главная", scr_home, ["Блок запуска: ИГРАТЬ (онлайн, на рейтинг), Против AI, С другом — жёлтые, одной группой.", "В блоке — полоса «Неделя льда» (не отдельная очередь). Слева — «3 друга в игре».", "Шапка: профиль → статистика, «Задания 1/3 · ×2 🏆», валюта, ⚙. Вкладка «Друзья»."],
             [(880, 200, 660, 220, "search", "ИГРАТЬ"), (880, 445, 320, 110, "ai", "Против AI"), (1220, 445, 320, 110, "friend", "С другом"),
              (880, 575, 660, 80, "weekly", "Неделя льда"), (110, 140, 420, 64, "blob", "Персонаж ✎"), (280, 470, 300, 300, "blob", "Блоб"),
              (110, 222, 420, 60, "friends", "3 друга в игре"), (30, 20, 320, 92, "profile", "Профиль"), (600, 28, 400, 60, "quests", "Задания дня"),
              (320, 800, 320, 100, "friends", "Вкладка «Друзья»"), (640, 800, 320, 100, "blob", "Вкладка «Блоб»"),
              (960, 800, 320, 100, "shop", "Вкладка «Магазин»"), (1280, 800, 320, 100, "leader", "Вкладка «Рейтинг»"), GEAR], None),
    "home_guest": ("Главная · гость", scr_home_guest, ["Браузер / ещё не сохранил: та же главная + мягкая плашка под блоком запуска.", "«ИГРАТЬ» не блокируется. Сохранение — по желанию, после интереса к прогрессу."],
                   [(1220, 745, 320, 44, "save", "Сохранить"), (880, 200, 660, 220, "search", "ИГРАТЬ"),
                    (880, 445, 320, 110, "ai", "Против AI"), (1220, 445, 320, 110, "friend", "С другом"), GEAR], None),
    "save": ("Сохранить прогресс", scr_save, ["Мягкий шит, не стена перед матчем. Google / Apple / Steam / код с телефона.", "Браузер: Google — основной; код — если уже есть прогресс на телефоне.", "«Позже» оставляет гостя. Пароль и email-формы нет."],
             [(1228, 143, 64, 64, "home_guest", "✕"), (360, 290, 880, 100, "account", "Google"),
              (360, 410, 880, 100, "account", "Apple"), (800, 530, 440, 90, "restore", "Код с телефона"),
              (480, 740, 640, 70, "home_guest", "Позже")], None),
    "account": ("Аккаунт", scr_account, ["Раздел настроек: Goofy ID + список входов (линковка).", "Линковка = привязать ещё один ключ (Apple, Steam, код) к тому же аккаунту.", "Прогресс не «переносится файлом» — ты просто входишь тем же профилем на другой платформе."],
                [BACK, (60, 498, 340, 76, "settings", "← к управлению"), (440, 455, 1100, 92, "link", "Добавить Apple"),
                 (440, 665, 1100, 92, "link", "Код устройства"), (440, 780, 520, 80, "link", "+ Добавить вход"),
                 (1000, 780, 540, 80, "restore", "Уже есть аккаунт?")], None),
    "link": ("Линковка", scr_link, ["Объяснение простым языком + выбор нового входа.", "Старый вход остаётся. Отвязка — позже, если остался хотя бы один способ."],
             [BACK, (60, 430, 1480, 92, "merge", "Apple (демо конфликта)"), (60, 540, 1480, 92, "account", "Steam"),
              (60, 650, 1480, 92, "restore", "Код для браузера"), (520, 820, 560, 70, "account", "Отмена")], None),
    "restore": ("Уже играл?", scr_restore, ["Вход существующим способом или код с другого устройства.", "После успеха — тот же Goofy ID, без второго профиля."],
                [(1228, 123, 64, 64, "account", "✕"), (360, 300, 880, 100, "account", "Google"),
                 (360, 420, 880, 100, "account", "Apple"), (360, 540, 880, 100, "account", "Код")], None),
    "merge": ("Два прогресса", scr_merge, ["Редкий кейс: привязали вход, у которого уже был другой аккаунт.", "Выбор основного + опция забрать косметику. Рейтинг — один (выше)."],
              [(360, 580, 300, 56, "account", "Оставить этот"), (360, 700, 400, 90, "account", "Объединить"),
               (840, 700, 400, 90, "link", "Отмена")], None),
    "friend": ("С другом", scr_friend, ["Модалка из двух вариантов: создать или войти по коду.", "Ссылка-приглашение открывает комнату сразу (в вебе — без установки).", "«Вдвоём на одном ПК» — только PC; на мобильных кнопки нет."],
               [FULL("home", "Тап мимо — закрыть"), (1213, 163, 64, 64, "home", "✕ Закрыть"), (390, 530, 340, 70, "room", "Создать"),
                (870, 530, 340, 70, "room", "Войти"), (440, 650, 720, 90, "hud", "Вдвоём на одном ПК")], None),
    "ai": ("Против AI", scr_ai, ["Один экран вместо мастера из шагов. Всё выбрано по умолчанию", "(последний выбор запоминается) — «Играть» можно жать сразу.", "«🎯 Испытания» — офлайн-задачи на мастерство, рядом с игрой против AI."],
           [BACK, GEAR, (1140, 770, 400, 100, "vs", "ИГРАТЬ"), (80, 770, 460, 100, "trials", "Испытания")], None),
    "search": ("Поиск соперника", scr_search, ["Одна очередь для всех: ищем близкого по рейтингу, диапазон растёт.", "Онлайн не делится на режимы — матч находится даже при малом онлайне.", "Отмена — крупная, снизу по центру. Совет дня обучает механикам."],
               [(620, 760, 360, 90, "home", "Отмена")], (2600, "vs")),
    "vs": ("VS", scr_vs, ["3 секунды: ники, персонажи, рейтинг и ставка (+ за победу / − за поражение).", "Сильнее соперник → больше за победу и меньше за поражение.", "«Ваши встречи 3 : 1» — личная история с этим соперником (соперничество)."],
           [], (2600, "hud")),
    "room": ("Комната", scr_room, ["Код огромный — его диктуют голосом. «Пригласить» = системный шаринг.", "Слоты по командам; пустой слот → «+ Бот». N команд × N игроков.", "Настройки — чипы-выпадашки в одну строку, меняет только хозяин."],
             [(42, 26, 68, 68, "home", "← Назад"), (1140, 760, 400, 100, "vs", "СТАРТ")], None),
    "hud": ("HUD 1×1", scr_hud, ["1 пауза (онлайн — меню) · 2 счёт и ники · 3 плашка события за 1–2 с", "4 движение: вся левая половина, drag от точки касания · 5 прыжок", "6 «Действие»: иконка бафа в слоте, пусто → 💥 самоуничтожение", "7 😀 эмоции — активны только между розыгрышами"],
            [FULL("point", "Тап — забить очко (демо)"), (38, 26, 64, 64, "pause", "⏸ Пауза"), (1508, 26, 64, 64, "emote", "😀 Эмоции")], (6000, "point")),
    "tutorial": ("Обучение (1-й запуск)", scr_tutorial, ["Настоящий матч против AI с подсказками поверх: 3 шага —", "движение, прыжок, «Действие». Можно пропустить в любой момент."],
                 [FULL("home", "Тап — завершить обучение (демо)"), (1380, 30, 190, 56, "home", "Пропустить")], None),
    "multi": ("3 команды", scr_multi, ["Вместо счёта — жизни каждой команды над её зоной.", "Плашки в цвете команды. Выбывшая зона гаснет и схлопывается."],
              [FULL("win", "Тап — к итогам (демо)"), (38, 26, 64, 64, "pause", "⏸ Пауза")], None),
    "point": ("Очко + повтор", scr_point, ["После яркого очка: кино-полосы, слоумо 0.5×, «ОЧКО!» и новый счёт.", "Момент сам сохраняется для клипа — ничего нажимать не нужно."],
              [FULL("win", "Тап — к итогам")], (2600, "win")),
    "pause": ("Пауза", scr_pause, ["Три большие кнопки, «Продолжить» — главная.", "Выход из онлайн-матча — с подтверждением (засчитывается поражение)."],
              [(580, 260, 440, 110, "back", "Продолжить"), (580, 400, 440, 95, "settings", "Настройки"), (580, 525, 440, 95, "lose", "Выйти")], None),
    "reconnect": ("Переподключение", scr_reconnect, ["Соперник отвалился — честный таймер и понятный исход.", "Свой плохой пинг — маленькая плашка справа сверху, не мешает игре."],
                  [FULL("win", "Тап — соперник не вернулся")], (3500, "win")),
    "win": ("Победа", lambda: scr_result(True), ["Справа: рейтинг со ставкой, монеты (×2 за первую победу дня, задание ✓).", "«Лучший момент» с превью — главный вирусный крючок. «Дальше» — главная.", "«BlobKing → в друзья»: случайный соперник становится другом в один тап."],
            [(880, 580, 310, 110, "vs", "Реванш"), (1210, 580, 330, 110, "rankup", "Дальше"), (905, 350, 280, 170, "share", "Превью момента"),
             (1210, 480, 310, 52, "share", "Поделиться"), (880, 710, 660, 76, "friends", "В друзья")], None),
    "lose": ("Поражение", lambda: scr_result(False), ["Та же раскладка. Главная кнопка — «Реванш».", "Совет против персонажа соперника вместо пустого «Вы проиграли»."],
             [(880, 580, 330, 110, "vs", "Реванш"), (1230, 580, 310, 110, "home", "Дальше"), (905, 350, 280, 170, "share", "Превью момента"),
              (1210, 480, 310, 52, "share", "Поделиться"), (880, 710, 660, 76, "friends", "В друзья")], None),
    "share": ("Поделиться клипом", scr_share, ["Превью 9:16 с водяным знаком и подписью. 4 переключателя, без редактора.", "Одна главная кнопка → системное меню шаринга (без логотипов соцсетей).", "«Вызов другу» — ссылка, которая открывает веб-версию."],
              [BACK], None),
    "rankup": ("Новый ранг", scr_rankup, ["Ранг — ступень единого рейтинга. Редкий попап: ранг + награда.", "Не больше одного попапа за раз; очередь наград — по порядку."],
               [(620, 780, 360, 90, "home", "Круто!")], None),
    "blob": ("Блоб", scr_blob, ["Слева примерка, справа сетка. Тап по предмету = надеть сразу.", "Замок показывает способ получения: цена, ранг, достижение, видео.", "«🎖 Коллекция 34/120» — общий прогресс и предметы за достижения."],
             [BACK, GEAR, (720, 770, 420, 100, "collection", "Коллекция")], None),
    "shop": ("Магазин", scr_shop, ["Сверху 3 предложения дня, снизу постоянные: без рекламы, набор, видео.", "Только косметика. Без батл-пасса и сундуков за деньги."],
             [BACK, GEAR], None),
    "leader": ("Рейтинг", scr_leader, ["Один экран без подвкладок, фильтры — чипами (в т.ч. «Друзья»).", "Своя строка всегда закреплена внизу. «Сезон 3» → награды за ранги."],
               [BACK, GEAR, (1140, 128, 400, 60, "season", "Сезон 3")], None),
    "settings": ("Настройки", scr_settings, ["Слева разделы, справа содержимое. Управление — первым:", "кнопки двигаются прямо на превью, размер и прозрачность — ползунки.", "Вкладка «Аккаунт» → экран линковки входов."],
                 [BACK, (60, 498, 340, 76, "account", "👤 Аккаунт")], None),
    "friends": ("Друзья", scr_friends, ["Вкладка «Друзья»: кто в игре, личный счёт с каждым, «Позвать» в один тап.", "Офлайн-другу — «Вызов» (ссылка в мессенджер, открывает веб-версию).", "Справа — своя компания: постоянная группа и таблица недели «кто кого»."],
                [BACK, GEAR, (1060, 128, 480, 60, "friend", "Ссылка-приглашение"), (790, 231, 190, 60, "room", "Позвать JellyBoi"),
                 (790, 441, 190, 60, "room", "Позвать GooGoo"), (790, 546, 190, 60, "share", "Вызов Splat"),
                 (1040, 215, 500, 512, "crew", "Компания «Слизни»")], None),
    "crew": ("Компания", scr_crew, ["Своя компания на 2–8 человек — дешёвая замена кланам.", "Постоянная комната с запомненными настройками + таблица недели «кто кого».", "«2×2 против случайных» — играть вместе важнее, чем друг против друга."],
             [BACK, GEAR, (820, 130, 720, 190, "room", "Играть вместе"), (820, 340, 720, 120, "search", "2×2 против случайных"),
              (820, 480, 720, 96, "invite", "Позвать всех (как это видит друг)")], None),
    "invite": ("Приглашение", scr_invite, ["Так друг видит «Позвать»: попап на главной, «Принять» → сразу в комнату.", "Во время матча — тихая плашка сверху, не прерывает игру."],
               [(460, 520, 420, 100, "room", "Принять"), (900, 520, 240, 100, "home", "Позже")], None),
    "quests": ("Задания дня", scr_quests, ["Повод зайти сегодня: ×2 за первую победу дня и 3 задания с монетами.", "Задания учат бафам («раздави потолком»), 1 замена в день. Есть задание недели.", "Никакой энергии и штрафов: пропущенные дни ничего не сжигают."],
               [BACK, GEAR, (1140, 660, 400, 110, "search", "ИГРАТЬ"), (60, 660, 1040, 110, "weekly", "Задание недели")], None),
    "weekly": ("Неделя льда", scr_weekly, ["Режим недели — не отдельная очередь: ледяной пол во всех онлайн-матчах недели.", "Новый баф + испытание + задание недели с шапкой. Анонс следующей недели.", "Против AI и в комнате неделю можно выбрать как пресет."],
               [BACK, GEAR, (860, 580, 680, 130, "search", "ИГРАТЬ"), (870, 345, 660, 50, "trials", "Испытание недели"), (870, 405, 660, 50, "quests", "Задание недели")], None),
    "news": ("Что нового", scr_news, ["Один раз после обновления: новый баф, персонаж, арена, баланс.", "«Попробовать против AI» — сразу пощупать новинку без риска для рейтинга.", "Ритм: новый баф или событие каждые 2–3 недели."],
             [(300, 680, 580, 100, "ai", "Попробовать против AI"), (900, 680, 400, 100, "home", "Ок")], None),
    "season": ("Сезон рейтинга", scr_season, ["Сезон 2–3 месяца, мягкий сброс. Награда-косметика за итоговый ранг.", "Ранги — ступени единого рейтинга. Без пасса и покупок.", "Полученное остаётся навсегда — «ветеранские» шапки."],
               [BACK, GEAR, (1140, 660, 400, 110, "search", "ИГРАТЬ")], None),
    "profile": ("Профиль", scr_profile, ["Мастерство: рейтинг за 30 дней, серия побед, смешная статистика.", "Уровни персонажей — растут от игры за персонажа (только косметика).", "Отсюда — испытания и коллекция."],
                [BACK, GEAR, (660, 670, 420, 100, "trials", "Испытания"), (1120, 670, 420, 100, "collection", "Коллекция")], None),
    "trials": ("Испытания", scr_trials, ["Короткие офлайн-задачи на механику: 30–60 с, 3 звезды.", "Учат скрытым приёмам, которые потом работают в рейтинге.", "Испытание недели меняется вместе с режимом недели."],
               [BACK, GEAR, (816, 215, 345, 265, "hud", "Гол через портал (запуск)"), (438, 500, 345, 265, "hud", "3 гола с отскока")], None),
    "collection": ("Коллекция", scr_collection, ["Общий прогресс 34/120 и по категориям — тап открывает вкладку «Блоб».", "Часть предметов — только за достижения: гордость, а не покупка.", "Всё видно в матче и в клипах — самовыражение и бесплатная реклама."],
                   [BACK, GEAR, (620, 140, 920, 78, "blob", "Шапки")], None),
    "emote": ("Эмоции", scr_emote, ["Быстрые эмоции над блобом — только между розыгрышами, на 2 с.", "Никакого свободного чата: аудитория молодая, эмоции безопасны.", "Новые эмоции — в коллекции и за достижения."],
              [(470, 780, 120, 84, "hud", "😂"), (605, 780, 120, 84, "hud", "😎"), (740, 780, 120, 84, "hud", "🤡"),
               (38, 26, 64, 64, "pause", "⏸ Пауза")], (2600, "hud")),
}

GROUPS = [
    ("ui-home", "Вход и главная", "UI — вход и главная", "главный экран = персонаж слева, жёлтый блок запуска справа", ["splash", "home", "friend", "ai"]),
    ("ui-auth", "Аккаунт", "UI — тихий вход и линковка", "аккаунт создаётся сам; сохранение и линковка — по желанию", ["home_guest", "save", "account", "link", "restore", "merge"]),
    ("ui-lobby", "Поиск и комната", "UI — поиск, VS и комната", "между тапом «Играть» и матчем — максимум два экрана", ["search", "vs", "room"]),
    ("ui-match", "Матч", "UI — матч", "минимум интерфейса: всё важное — внутри арены", ["hud", "tutorial", "multi", "point", "pause", "reconnect"]),
    ("ui-results", "Итоги", "UI — итоги и клипы", "после матча: результат, награды и одна кнопка «Поделиться»", ["win", "lose", "share", "rankup"]),
    ("ui-meta", "Меню", "UI — блоб, магазин, рейтинг, настройки", "вкладки нижней навигации и настройки", ["blob", "shop", "leader", "settings"]),
    ("ui-social", "Друзья", "UI — друзья и компания", "главный рычаг удержания: играть вместе, а не только против", ["friends", "crew", "invite"]),
    ("ui-habit", "Привычка и контент", "UI — задания, неделя, обновления, сезон", "повод зайти сегодня и что нового — без энергии и штрафов", ["quests", "weekly", "news", "season"]),
    ("ui-mastery", "Мастерство и коллекция", "UI — профиль, испытания, коллекция, эмоции", "глубина под хаосом и самовыражение", ["profile", "trials", "collection", "emote"]),
]


# ---------- clickable HTML prototype ----------
PROTO_CSS = """
:root{--bg:#010310;--bg1:#05091F;--panel:#0A1030;--panel2:#111A3F;--text:#E8F0FF;--sub:#7A8BB5;--ball:#FFD20A;--cyan:#03B8FF;--mag:#FF05AD;--line:#2C3658}
*{box-sizing:border-box}html,body{margin:0}
body{background:radial-gradient(ellipse at 50% 30%,var(--bg1),var(--bg) 70%) fixed;color:var(--text);font-family:Nunito,'Segoe UI',system-ui,sans-serif;min-height:100vh}
button{font:inherit;color:inherit;cursor:pointer}
.app{display:grid;grid-template-columns:250px 1fr;min-height:100vh}
aside{border-right:1px solid var(--line);padding:20px 14px;position:sticky;top:0;height:100vh;overflow:auto}
aside h1{font-size:20px;font-weight:900;margin:0 0 4px 8px;letter-spacing:.5px}
aside h1 b{color:var(--cyan)}aside h1 i{color:var(--mag);font-style:normal}
aside .lead{color:var(--sub);font-size:13px;margin:0 0 18px 8px}
aside h2{font-size:12px;text-transform:uppercase;letter-spacing:1.2px;color:var(--sub);margin:16px 8px 6px}
aside nav button{display:block;width:100%;text-align:left;background:none;border:0;border-radius:10px;padding:7px 10px;font-size:15px;font-weight:700;color:var(--text)}
aside nav button:hover{background:var(--panel2)}
aside nav button.on{background:var(--ball);color:#170F00}
main{padding:20px clamp(12px,3vw,40px) 40px;display:flex;flex-direction:column;align-items:center;gap:16px;min-width:0}
.bar{display:flex;gap:8px;flex-wrap:wrap;justify-content:center}
.bar button{background:var(--panel2);border:2px solid var(--line);border-radius:22px;padding:8px 16px;font-weight:800;font-size:14px}
.bar button:hover{border-color:var(--cyan)}.bar button.on{border-color:var(--ball);color:var(--ball)}
.phone{position:relative;width:min(100%,calc((100vh - 260px)*16/9),1280px);min-width:280px;aspect-ratio:16/9;border:12px solid #151B33;outline:3px solid var(--line);border-radius:38px;overflow:hidden;background:var(--bg)}
.scr{position:absolute;inset:0;display:none}
.scr.on{display:block;animation:enter .3s ease}
@keyframes enter{from{opacity:0;transform:scale(1.03)}to{opacity:1;transform:none}}
.scr svg{display:block;width:100%;height:100%}
.hot{position:absolute;background:transparent;border:0;padding:0;border-radius:14px;outline:none}
.hot:focus-visible{box-shadow:0 0 0 3px var(--ball)}
.show-hot .hot,.flash .hot{background:rgba(255,210,10,.14);box-shadow:inset 0 0 0 2px rgba(255,210,10,.85)}
.hot.full{border-radius:0}.show-hot .hot.full,.flash .hot.full{background:transparent;box-shadow:inset 0 0 0 2px rgba(255,210,10,.3)}
.timer{position:absolute;left:0;bottom:0;height:5px;background:var(--ball);width:0;box-shadow:0 0 10px var(--ball)}
.info{width:min(100%,1280px);display:grid;grid-template-columns:minmax(0,1.2fr) minmax(0,1fr);gap:8px 24px;align-items:start}
.info h3{margin:0;font-size:24px;font-weight:900}
.info .crumb{color:var(--sub);font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:1px}
.info ul{margin:6px 0 0;padding-left:18px;color:#C3CDE6;font-size:15px;line-height:1.5}
.links{display:flex;flex-wrap:wrap;gap:6px;justify-content:flex-end}
.links span{width:100%;text-align:right;color:var(--sub);font-size:12px;font-weight:800;text-transform:uppercase;letter-spacing:1px}
.links button{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:5px 12px;font-size:13px;font-weight:700}
.links button:hover{border-color:var(--ball);color:var(--ball)}
.links .auto{border-style:dashed;color:var(--sub)}
.map{position:fixed;inset:0;background:rgba(1,3,16,.92);display:none;align-items:center;justify-content:center;padding:24px;z-index:9}
.map.on{display:flex;flex-direction:column}.map svg{width:min(100%,1600px);height:auto;max-height:calc(100vh - 80px);cursor:default}
.map .map-hint{color:var(--sub);font-size:14px;font-weight:700;margin-bottom:8px;text-align:center}
.map button.close{position:absolute;top:16px;right:20px;background:var(--panel2);border:2px solid var(--line);border-radius:22px;padding:8px 16px;font-weight:800}
.map .map-node{cursor:pointer;outline:none}
.map .map-node rect{pointer-events:all}
.map .map-node text{pointer-events:none}
.map .map-node:hover rect,.map .map-node:focus-within rect{stroke:#FFD20A!important;stroke-width:6px}
@media (max-width:900px){.app{grid-template-columns:1fr}aside{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line);padding:12px}
aside nav{display:flex;gap:4px;overflow-x:auto}aside h2{display:none}aside nav button{white-space:nowrap;width:auto}
.phone{width:100%;border-width:6px;border-radius:20px}.info{grid-template-columns:1fr}.links{justify-content:flex-start}.links span{text-align:left}}
"""

PROTO_JS = """
const S = DATA, scr = {}, hist = [];
let cur = null, timer = null, raf = null;
document.querySelectorAll('.scr').forEach(e => scr[e.dataset.k] = e);
const $ = s => document.querySelector(s), phone = $('.phone'), bar = $('.timer');
function go(t) {
  if (t === 'back') { t = hist.pop() || 'home'; show(t); return; }
  if (cur && cur !== t) hist.push(cur);
  show(t);
}
function show(k) {
  if (!S[k]) k = 'splash';
  clearTimeout(timer); cancelAnimationFrame(raf); bar.style.width = 0;
  if (cur) scr[cur].classList.remove('on');
  scr[k].classList.add('on'); cur = k;
  const s = S[k];
  $('#crumb').textContent = s.group; $('#title').textContent = s.title;
  $('#notes').innerHTML = s.notes.map(n => '<li>' + n + '</li>').join('');
  const links = s.hot.filter(h => h[4]).map(h => `<button data-t="${h[4]}">${h[5]} → ${h[4] === 'back' ? 'назад' : S[h[4]].title}</button>`);
  if (s.auto) links.push(`<button class="auto" data-t="${s.auto[1]}">авто ${s.auto[0] / 1000} с → ${S[s.auto[1]].title}</button>`);
  $('#links').innerHTML = '<span>Переходы</span>' + (links.join('') || '<button disabled>—</button>');
  document.querySelectorAll('aside nav button').forEach(b => b.classList.toggle('on', b.dataset.k === k));
  history.replaceState(null, '', '#' + k);
  if (s.auto) {
    const t0 = performance.now(), d = s.auto[0];
    const tick = now => { bar.style.width = Math.min(100, (now - t0) / d * 100) + '%'; if (now - t0 < d) raf = requestAnimationFrame(tick); };
    raf = requestAnimationFrame(tick);
    timer = setTimeout(() => go(s.auto[1]), d);
  }
}
function closeMap() { $('.map').classList.remove('on'); }
function openFromMap(k) {
  closeMap(); hist.length = 0; show(k);
}
document.addEventListener('click', e => {
  // Map nodes: close overlay then jump (don't leave map open over the new screen)
  const mapNode = e.target.closest('.map-node');
  if (mapNode && mapNode.closest('.map') && mapNode.dataset.t) {
    e.preventDefault();
    openFromMap(mapNode.dataset.t);
    return;
  }
  if (e.target.closest('.map .close')) { closeMap(); return; }
  const b = e.target.closest('[data-t]'); if (b) { go(b.dataset.t); return; }
  const n = e.target.closest('aside nav button'); if (n) { hist.length = 0; show(n.dataset.k); return; }
  if (e.target.closest('.phone')) { phone.classList.add('flash'); setTimeout(() => phone.classList.remove('flash'), 350); }
});
document.addEventListener('keydown', e => {
  if ((e.key === 'Enter' || e.key === ' ') && document.activeElement && document.activeElement.classList.contains('map-node')) {
    e.preventDefault(); openFromMap(document.activeElement.dataset.t); return;
  }
  if (e.key === 'Escape') closeMap();
  if (e.key === 'Backspace' || e.key === 'ArrowLeft') go('back');
  if (e.key === 'h' || e.key === 'р') $('#hot').click();
});
$('#restart').onclick = () => { hist.length = 0; cur && scr[cur].classList.remove('on'); cur = null; show('splash'); };
$('#hot').onclick = e => { document.body.classList.toggle('show-hot'); e.currentTarget.classList.toggle('on'); };
$('#mapbtn').onclick = () => $('.map').classList.add('on');
show(location.hash.slice(1) || 'splash');
"""

def build_prototype(flow_svg_path):
    import html, json, re
    from generate_concepts import defs as svg_defs
    colors = {k: C[k] for k in ("cyan", "mag", "lime", "orange", "buff")}
    group_of = {k: g[1] for g in GROUPS for k in g[4]}
    screens, nav, data = [], [], {}
    for _, gname, _, _, keys in GROUPS:
        nav.append(f"<h2>{gname}</h2><nav>" + "".join(f"<button data-k='{k}'>{html.escape(SCREENS[k][0])}</button>" for k in keys) + "</nav>")
    for k, (title, fn, notes, hot, auto) in SCREENS.items():
        hs = []
        for (x, y, w, h, t, lab) in sorted(hot, key=lambda h: -h[2] * h[3]):
            cls = "hot full" if w * h >= 1600 * 900 else "hot"
            hs.append(f"<button class='{cls}' data-t='{t}' aria-label='{html.escape(lab)}' title='{html.escape(lab)}' "
                      f"style='left:{x/16:.3f}%;top:{y/9:.3f}%;width:{w/16:.3f}%;height:{h/9:.3f}%'></button>")
        screens.append(f"<div class='scr' data-k='{k}'><svg viewBox='0 0 1600 900' preserveAspectRatio='xMidYMid meet' role='img' aria-label='{html.escape(title)}'>"
                       f"<rect width='1600' height='900' fill='url(#bgG)'/>{fn()}</svg>{''.join(hs)}</div>")
        data[k] = dict(title=title, group=group_of[k], notes=[html.escape(n) for n in notes], hot=[list(h) for h in hot], auto=list(auto) if auto else None)
    flow = open(flow_svg_path, encoding="utf-8").read()
    # strip width/height so the overlay scales; keep viewBox from sheet_flow
    flow = re.sub(r"^<svg[^>]*>",
                  lambda m: re.sub(r"\s(width|height)='[^']*'", "", m.group(0)),
                  flow, count=1)
    page = f"""<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Goofy Ball UI</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;700;800;900&display=swap" rel="stylesheet">
<style>{PROTO_CSS}</style></head><body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true">{svg_defs(colors)}</svg>
<div class="app"><aside><h1><b>GOOFY</b> <i>BALL</i></h1><p class="lead">Кликабельный прототип UI · 1600×900</p>{''.join(nav)}</aside>
<main><div class="bar"><button id="restart">⟲ С начала</button><button id="hot">▢ Подсветить клики (H)</button><button id="mapbtn">🗺 Карта экранов</button><button data-t="back">← Назад</button></div>
<div class="phone">{''.join(screens)}<div class="timer"></div></div>
<div class="info"><div><div class="crumb" id="crumb"></div><h3 id="title"></h3><ul id="notes"></ul></div><div class="links" id="links"></div></div>
</main></div>
<div class="map" role="dialog" aria-label="Карта экранов"><button class="close" type="button">✕ Закрыть</button>
<p class="map-hint">Клик по окну на карте → открыть этот экран</p>{flow}</div>
<script>const DATA = {json.dumps(data, ensure_ascii=False)};{PROTO_JS}</script></body></html>"""
    path = os.path.join(OUT, "ui-prototype.html")
    with open(path, "w", encoding="utf-8") as f:
        f.write(page)
    return path


# ---------- sheets ----------
def build():
    flow = sheet_flow()
    yield flow
    for name, _, title, subtitle, keys in GROUPS:
        yield sheet(name, title, subtitle, [(SCREENS[k][0], SCREENS[k][1](), SCREENS[k][2]) for k in keys])
    print("ok", os.path.basename(build_prototype(flow[0])))


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
