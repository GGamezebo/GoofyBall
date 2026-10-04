import os, math
OUT = os.path.dirname(os.path.abspath(__file__))
C = dict(bg0="#010310", bg1="#05091F", floor="#1A2340", cyan="#03B8FF", mag="#FF05AD",
         lime="#7CFF4F", orange="#FF8A1F", ball="#FFD20A", buff="#9B5CFF", danger="#FF3B3B",
         text="#E8F0FF", sub="#7A8BB5")
FONT = "font-family='Arial Rounded MT Bold, Nunito, Arial, sans-serif'"

def lighten(hexc, k=0.55):
    h = hexc.lstrip('#'); r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    r, g, b = (int(v + (255 - v) * k) for v in (r, g, b))
    return f"#{r:02X}{g:02X}{b:02X}"

def defs(colors):
    s = ["<defs>",
         "<filter id='glow' x='-50%' y='-50%' width='200%' height='200%'><feGaussianBlur stdDeviation='6' result='b'/><feMerge><feMergeNode in='b'/><feMergeNode in='SourceGraphic'/></feMerge></filter>",
         "<filter id='glowBig' x='-80%' y='-80%' width='260%' height='260%'><feGaussianBlur stdDeviation='14' result='b'/><feMerge><feMergeNode in='b'/><feMergeNode in='b'/><feMergeNode in='SourceGraphic'/></feMerge></filter>",
         "<filter id='soft'><feGaussianBlur stdDeviation='30'/></filter>",
         f"<radialGradient id='bgG' cx='50%' cy='40%' r='75%'><stop offset='0' stop-color='{C['bg1']}'/><stop offset='1' stop-color='{C['bg0']}'/></radialGradient>",
         f"<radialGradient id='ballG' cx='35%' cy='30%' r='70%'><stop offset='0' stop-color='#FFF6C2'/><stop offset='0.5' stop-color='{C['ball']}'/><stop offset='1' stop-color='#C98F00'/></radialGradient>"]
    for name, col in colors.items():
        s.append(f"<radialGradient id='g_{name}' cx='40%' cy='35%' r='75%'><stop offset='0' stop-color='{lighten(col, 0.6)}'/><stop offset='0.55' stop-color='{col}'/><stop offset='1' stop-color='{col}' stop-opacity='0.85'/></radialGradient>")
    s.append("</defs>")
    return "".join(s)

def svg(w, h, body, colors=None):
    colors = colors or {k: C[k] for k in ("cyan", "mag", "lime", "orange", "buff")}
    return (f"<svg xmlns='http://www.w3.org/2000/svg' width='{w}' height='{h}' viewBox='0 0 {w} {h}'>"
            + defs(colors) + f"<rect width='{w}' height='{h}' fill='url(#bgG)'/>" + body + "</svg>")

def text(x, y, t, size=28, col=None, anchor="middle", weight="bold", extra=""):
    return f"<text x='{x}' y='{y}' {FONT} font-size='{size}' font-weight='{weight}' fill='{col or C['text']}' text-anchor='{anchor}' {extra}>{t}</text>"

def eyes(x, y, r, mood, look=0.0):
    ex = r * 0.32; ey = -r * 0.42; er = r * 0.2
    out = []
    for sx in (-1, 1):
        cx, cy = x + sx * ex, y + ey
        if mood == "dead":
            d = er * 0.8
            out.append(f"<path d='M{cx-d},{cy-d} L{cx+d},{cy+d} M{cx+d},{cy-d} L{cx-d},{cy+d}' stroke='#0A0F25' stroke-width='{r*0.07}' stroke-linecap='round'/>")
            continue
        ry = er * (1.35 if mood == "scared" else 1.1)
        out.append(f"<ellipse cx='{cx}' cy='{cy}' rx='{er}' ry='{ry}' fill='white'/>")
        pr = er * (0.35 if mood == "scared" else 0.55)
        out.append(f"<circle cx='{cx + look*er*0.4}' cy='{cy + er*0.15}' r='{pr}' fill='#0A0F25'/>")
        if mood in ("angry", "smug"):
            tilt = 1 if mood == "angry" else -1
            out.append(f"<path d='M{cx-er*1.1},{cy-ry-er*0.2 - sx*tilt*er*0.35} L{cx+er*1.1},{cy-ry-er*0.2 + sx*tilt*er*0.35}' stroke='#0A0F25' stroke-width='{r*0.06}' stroke-linecap='round'/>")
    my = y - r * 0.1
    if mood == "happy":
        out.append(f"<path d='M{x-r*0.18},{my} Q{x},{my+r*0.2} {x+r*0.18},{my}' stroke='#0A0F25' stroke-width='{r*0.06}' fill='none' stroke-linecap='round'/>")
    elif mood == "scared":
        out.append(f"<ellipse cx='{x}' cy='{my+r*0.05}' rx='{r*0.1}' ry='{r*0.14}' fill='#0A0F25'/>")
    elif mood == "smug":
        out.append(f"<path d='M{x-r*0.2},{my+r*0.05} Q{x+r*0.05},{my+r*0.15} {x+r*0.22},{my-r*0.06}' stroke='#0A0F25' stroke-width='{r*0.06}' fill='none' stroke-linecap='round'/>")
    elif mood == "angry":
        out.append(f"<path d='M{x-r*0.15},{my+r*0.08} L{x+r*0.15},{my+r*0.08}' stroke='#0A0F25' stroke-width='{r*0.06}' stroke-linecap='round'/>")
    elif mood == "dead":
        out.append(f"<path d='M{x-r*0.15},{my+r*0.05} Q{x},{my-r*0.05} {x+r*0.15},{my+r*0.05}' stroke='#0A0F25' stroke-width='{r*0.05}' fill='none'/>")
    return "".join(out)

def blob(x, y, r, col, mood="happy", sx=1.0, sy=1.0, look=0.0, dent=0.0, glow=True, opacity=1.0,
         ground=True, floor_y=None):
    """Round slime ball. (x, y) = lowest point of the blob. Default shape is a circle,
    slightly flattened when resting on the floor; sx/sy squash & stretch (keep sx*sy ~ 1)."""
    cname = {v: k for k, v in C.items()}.get(col, "cyan")
    if ground:
        sy *= 0.93
    w = r * sx; hh = r * sy
    cx, cy = x, y - hh
    k = 0.5523; kb = k + (0.22 if ground else 0.0)  # flatter bottom when touching the floor
    top = cy - hh + dent * hh * 2
    d = (f"M{cx-w},{cy} C{cx-w},{cy-hh*k} {cx-w*k},{top} {cx},{top} "
         f"C{cx+w*k},{top} {cx+w},{cy-hh*k} {cx+w},{cy} "
         f"C{cx+w},{cy+hh*kb} {cx+w*kb},{cy+hh} {cx},{cy+hh} "
         f"C{cx-w*kb},{cy+hh} {cx-w},{cy+hh*kb} {cx-w},{cy} Z")
    f = " filter='url(#glow)'" if glow else ""
    fy = y if floor_y is None else floor_y
    shadow_k = max(0.25, 1.0 - (fy - y) / (r * 5.0))
    re = r * min(1.0, (sx + sy) / 2)
    out = [f"<g opacity='{opacity}'>",
           f"<ellipse cx='{x}' cy='{fy+r*0.05}' rx='{w*0.9*shadow_k}' ry='{r*0.1*shadow_k}' fill='#000' opacity='{0.5*shadow_k:.2f}'/>",
           f"<path d='{d}' fill='url(#g_{cname})' stroke='{lighten(col,0.35)}' stroke-width='{r*0.07}'{f}/>",
           f"<ellipse cx='{cx-w*0.42}' cy='{cy-hh*0.52}' rx='{w*0.22}' ry='{hh*0.12}' fill='white' opacity='0.75' transform='rotate(-35 {cx-w*0.42} {cy-hh*0.52})'/>",
           f"<circle cx='{cx-w*0.12}' cy='{cy-hh*0.72}' r='{r*0.05}' fill='white' opacity='0.8'/>",
           eyes(cx, cy - hh * 0.05 + re * 0.42, re, mood, look),
           "</g>"]
    return "".join(out)

def dust(x, y, s=1.0):
    return "".join(f"<circle cx='{x+dx*s}' cy='{y-dy*s}' r='{rr*s}' fill='#B8C4E8' opacity='0.35'/>"
                   for dx, dy, rr in ((-55, 8, 10), (-35, 18, 7), (40, 10, 9), (60, 22, 6), (-70, 25, 5)))

def ball(x, y, r, trail=None):
    out = []
    if trail:
        dx, dy = trail
        for i in range(1, 5):
            out.append(f"<circle cx='{x-dx*i}' cy='{y-dy*i}' r='{r*(1-i*0.17)}' fill='{C['ball']}' opacity='{0.28-i*0.05}'/>")
    out.append(f"<circle cx='{x}' cy='{y}' r='{r}' fill='url(#ballG)' filter='url(#glowBig)'/>")
    out.append(f"<path d='M{x-r},{y} Q{x},{y-r*0.5} {x+r},{y} M{x},{y-r} Q{x+r*0.45},{y} {x},{y+r}' stroke='#B07B00' stroke-width='{r*0.08}' fill='none' opacity='0.6'/>")
    return "".join(out)

def limb(x1, y1, x2, y2, col, bend=30, end="fist", w=12):
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    dx, dy = x2 - x1, y2 - y1; L = math.hypot(dx, dy) or 1
    cx, cy = mx - dy / L * bend, my + dx / L * bend
    lc = lighten(col, 0.25)
    out = [f"<path d='M{x1},{y1} Q{cx},{cy} {x2},{y2}' stroke='{lc}' stroke-width='{w}' fill='none' stroke-linecap='round' filter='url(#glow)'/>"]
    if end == "fist":
        out.append(f"<circle cx='{x2}' cy='{y2}' r='{w*1.3}' fill='{lc}' stroke='white' stroke-width='3'/>")
    elif end == "glove":
        out.append(f"<ellipse cx='{x2}' cy='{y2}' rx='{w*1.8}' ry='{w*1.5}' fill='{C['danger']}' stroke='white' stroke-width='3'/>")
    elif end == "boot":
        ang = math.degrees(math.atan2(dy, dx))
        out.append(f"<g transform='rotate({ang} {x2} {y2})'><rect x='{x2-w}' y='{y2-w*1.2}' width='{w*3.2}' height='{w*2.2}' rx='{w*0.9}' fill='#F2F2F2' stroke='{lc}' stroke-width='3'/><rect x='{x2-w}' y='{y2+w*0.6}' width='{w*3.2}' height='{w*0.5}' fill='{C['danger']}'/></g>")
    return "".join(out)

def burst(x, y, r, col, n=12):
    pts = []
    for i in range(n * 2):
        a = math.pi * i / n; rr = r if i % 2 == 0 else r * 0.55
        pts.append(f"{x+math.cos(a)*rr:.1f},{y+math.sin(a)*rr:.1f}")
    return f"<polygon points='{' '.join(pts)}' fill='{col}' opacity='0.9' filter='url(#glowBig)'/>"

def stars(w, h, n=60, seed=3):
    import random; rnd = random.Random(seed); out = []
    for _ in range(n):
        out.append(f"<circle cx='{rnd.uniform(0,w):.0f}' cy='{rnd.uniform(0,h*0.8):.0f}' r='{rnd.uniform(0.6,2):.1f}' fill='{rnd.choice([C['cyan'],C['mag'],'#ffffff'])}' opacity='{rnd.uniform(0.15,0.5):.2f}'/>")
    return "".join(out)

def court(x0, x1, floor_y, ceil_y, nets, colA=None):
    out = [f"<rect x='{x0}' y='{floor_y}' width='{x1-x0}' height='14' fill='{C['floor']}'/>",
           f"<rect x='{x0}' y='{floor_y-2}' width='{x1-x0}' height='4' fill='{C['cyan']}' filter='url(#glow)' opacity='0.9'/>",
           f"<rect x='{x0}' y='{ceil_y}' width='{x1-x0}' height='{floor_y-ceil_y}' fill='none' stroke='{C['cyan']}' stroke-width='2' opacity='0.25' rx='6'/>"]
    for nx, nh in nets:
        out.append(f"<rect x='{nx-4}' y='{floor_y-nh}' width='8' height='{nh}' fill='{lighten(C['cyan'],0.6)}' filter='url(#glow)' rx='4'/>")
        out.append(f"<circle cx='{nx}' cy='{floor_y-nh}' r='8' fill='white' filter='url(#glow)'/>")
    return "".join(out)

def pickup(x, y, icon, col=None, s=1.0):
    col = col or C['buff']
    return (f"<g filter='url(#glow)'><rect x='{x-26*s}' y='{y-26*s}' width='{52*s}' height='{52*s}' rx='{16*s}' fill='{col}' opacity='0.25' stroke='{col}' stroke-width='3'/></g>"
            + f"<text x='{x}' y='{y+11*s}' font-size='{32*s}' text-anchor='middle'>{icon}</text>")

def save(name, body):
    with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as f:
        f.write(body)

# ---------- 1. blobs sheet ----------
def sheet_blobs():
    W, H = 1600, 1100
    b = [stars(W, H, 40), text(W/2, 70, "GOOFY BALL — блобы", 46, C['text']),
         text(W/2, 110, "персонажи · эмоции · деформация · конечности от бафов", 24, C['sub'], weight="normal")]
    chars = [("cyan", "Прыгун", "прыжок +25%", 1.0, 1.0, "happy"),
             ("mag", "Толстяк", "тяжёлый, мощный отскок", 1.3, 0.85, "smug"),
             ("lime", "Липкий", "мяч прилипает", 1.0, 1.0, "happy"),
             ("orange", "Резиновый", "тянется сильнее", 0.9, 1.2, "angry"),
             ("buff", "Шустрик", "быстрый, бьёт слабее", 0.85, 0.95, "happy")]
    y = 360
    for i, (c, n, p, sx, sy, mood) in enumerate(chars):
        x = 190 + i * 305
        b.append(blob(x, y, 90, C[c], mood, sx, sy, look=0.3))
        b.append(text(x, y + 55, n, 30)); b.append(text(x, y + 88, p, 20, C['sub'], weight="normal"))
    # deformations row
    y2 = 700
    b.append(text(70, 530, "ДЕФОРМАЦИЯ", 24, C['cyan'], anchor="start"))
    defs_ = [("приземление", 1.45, 0.55, "happy", 0), ("прыжок", 0.75, 1.4, "happy", 0),
             ("удар мячом", 1.05, 0.95, "scared", 0.18), ("ужас", 1.0, 1.05, "scared", 0),
             ("взорвался", 1.0, 1.0, "dead", 0)]
    for i, (n, sx, sy, mood, dent) in enumerate(defs_):
        x = 190 + i * 305
        if n == "взорвался":
            b.append(burst(x, y2 - 70, 95, C['orange'])); b.append(burst(x, y2 - 70, 55, C['ball']))
            b.append(blob(x, y2, 55, C['cyan'], "dead", 1.6, 0.35, opacity=0.9))
        else:
            b.append(blob(x, y2, 75, C['cyan'], mood, sx, sy, dent=dent))
            if n == "удар мячом":
                b.append(ball(x + 10, y2 - 133, 30))
            if n == "прыжок":
                b.append(f"<path d='M{x-70},{y2-40} l0,30 M{x+70},{y2-40} l0,30 M{x-55},{y2-110} l0,22 M{x+55},{y2-110} l0,22' stroke='{C['cyan']}' stroke-width='4' opacity='0.5' stroke-linecap='round'/>")
        b.append(text(x, y2 + 50, n, 22, C['sub'], weight="normal"))
    # limbs row
    y3 = 1030
    b.append(text(70, 810, "КОНЕЧНОСТИ ОТ БАФОВ", 24, C['mag'], anchor="start"))
    # leg kick
    x = 260; b.append(limb(x + 40, y3 - 30, x + 150, y3 - 80, C['mag'], -25, "boot", 13))
    b.append(blob(x, y3, 65, C['mag'], "angry", look=1)); b.append(ball(x + 205, y3 - 105, 26, trail=(-16, 8)))
    b.append(text(x + 60, y3 + 40, "Супер-нога", 22, C['sub'], weight="normal"))
    # arms grab
    x = 760; b.append(limb(x - 45, y3 - 60, x - 70, y3 - 160, C['lime'], -30, "fist", 11))
    b.append(limb(x + 45, y3 - 60, x + 70, y3 - 160, C['lime'], 30, "fist", 11))
    b.append(ball(x, y3 - 175, 28)); b.append(blob(x, y3, 65, C['lime'], "smug"))
    b.append(text(x, y3 + 40, "Руки-хваталки", 22, C['sub'], weight="normal"))
    # boxing gloves
    x = 1260; b.append(limb(x + 45, y3 - 55, x + 160, y3 - 65, C['orange'], 25, "glove", 11))
    b.append(limb(x - 45, y3 - 55, x - 120, y3 - 20, C['orange'], -20, "glove", 11))
    b.append(blob(x, y3, 65, C['orange'], "angry", look=1))
    b.append(text(x, y3 + 40, "Боксёр (скин рук)", 22, C['sub'], weight="normal"))
    save("blobs", svg(W, H, "".join(b)))

# ---------- 2. gameplay mockup ----------
def sheet_gameplay():
    W, H = 1600, 900
    floor = 760; ceil = 120
    b = [stars(W, H, 70),
         f"<ellipse cx='400' cy='300' rx='380' ry='160' fill='{C['cyan']}' opacity='0.06' filter='url(#soft)'/>",
         f"<ellipse cx='1200' cy='280' rx='380' ry='160' fill='{C['mag']}' opacity='0.06' filter='url(#soft)'/>",
         court(60, 1540, floor, ceil, [(800, 230)])]
    # HUD
    b.append(f"<rect x='620' y='22' width='360' height='78' rx='20' fill='#0A1030' stroke='{C['sub']}' stroke-opacity='0.4'/>")
    b.append(text(720, 78, "4", 52, C['cyan'])); b.append(text(800, 76, ":", 44, C['sub'])); b.append(text(880, 78, "3", 52, C['mag']))
    b.append(text(230, 70, "YOU", 30, C['cyan'])); b.append(text(1370, 70, "SLIMEKING", 30, C['mag']))
    # env warning
    b.append(f"<g filter='url(#glow)'><rect x='600' y='140' width='400' height='64' rx='18' fill='{C['danger']}' opacity='0.18' stroke='{C['danger']}' stroke-width='3'/></g>")
    b.append(text(800, 183, "⚠ НЛО через 2…", 34, "#FFD0D0"))
    # ufo silhouette top right
    ux, uy = 1260, 210
    b.append(f"<g filter='url(#glow)' opacity='0.85'><ellipse cx='{ux}' cy='{uy}' rx='70' ry='20' fill='#3a3f5a' stroke='{C['lime']}' stroke-width='3'/><ellipse cx='{ux}' cy='{uy-14}' rx='32' ry='22' fill='{C['lime']}' opacity='0.5'/></g>")
    b.append(f"<polygon points='{ux-30},{uy+18} {ux+30},{uy+18} {ux+90},{floor} {ux-90},{floor}' fill='{C['lime']}' opacity='0.07'/>")
    # players
    b.append(blob(500, floor - 190, 66, C['cyan'], "angry", 0.9, 1.12, look=1, ground=False, floor_y=floor))
    b.append(f"<path d='M478,{floor-170} l0,45 M500,{floor-174} l0,60 M522,{floor-170} l0,45' stroke='{C['cyan']}' opacity='0.35' stroke-width='4' stroke-linecap='round'/>")
    b.append(blob(1150, floor, 66, C['mag'], "scared", look=-1))
    b.append(ball(640, 360, 34, trail=(-22, 18)))
    # pickups
    b.append(pickup(260, 470, "🍄")); b.append(pickup(1000, 420, "🌀"))
    # touch controls
    b.append(f"<circle cx='210' cy='810' r='70' fill='white' opacity='0.06' stroke='white' stroke-opacity='0.25' stroke-width='3'/>")
    b.append(f"<circle cx='235' cy='805' r='30' fill='white' opacity='0.2'/>")
    b.append(f"<circle cx='1300' cy='815' r='58' fill='{C['cyan']}' opacity='0.15' stroke='{C['cyan']}' stroke-width='3' filter='url(#glow)'/>")
    b.append(text(1300, 826, "⤒", 40, C['cyan']))
    b.append(f"<circle cx='1450' cy='760' r='66' fill='{C['buff']}' opacity='0.2' stroke='{C['buff']}' stroke-width='4' filter='url(#glow)'/>")
    b.append(text(1450, 776, "🍄", 44)); b.append(text(1450, 852, "ДЕЙСТВИЕ", 18, C['sub']))
    b.append(text(210, 893, "движение (drag)", 17, C['sub'], weight="normal"))
    b.append(text(1300, 893, "прыжок", 17, C['sub'], weight="normal"))
    save("gameplay", svg(W, H, "".join(b)))

# ---------- 3. buff icons ----------
def sheet_buffs():
    W, H = 1600, 1350
    b = [stars(W, H, 40), text(W/2, 70, "Бафы и события", 46),
         text(W/2, 108, "фиолетовый — пикапы (кнопка «Действие») · жёлтый — пассивки · красный — события окружения", 22, C['sub'], weight="normal")]
    rows = [
        (C['buff'], "ПИКАПЫ", [("🍄", "Гигант ×2"), ("🌀", "Портал"), ("🦵", "Супер-нога"), ("🙌", "Руки"), ("🔨", "Пробить потолок"),
                               ("🧲", "Магнит"), ("🐜", "Мини-соперник"), ("👯", "Клон"), ("🛝", "Батут"), ("🍬", "Жвачка")]),
        (C['ball'], "ПАССИВКИ", [("🐸", "Прыгун"), ("🐷", "Толстяк"), ("🍯", "Липкий"), ("🪀", "Резиновый"), ("⚡", "Шустрик")]),
        (C['danger'], "СОБЫТИЯ", [("🌙", "Луна"), ("🪐", "Тяжёлая планета"), ("📏", "Сетка ↕"), ("📐", "Наклон"), ("🙃", "Вверх ногами"),
                                 ("🛸", "НЛО"), ("🚀", "Ускорение"), ("🎁", "Дождь бафов"), ("⚽", "Мультимяч"), ("🌋", "Землетрясение"),
                                 ("🌬️", "Ветер"), ("🧊", "Лёд"), ("🌑", "Темнота")]),
    ]
    y = 190
    for col, title, items in rows:
        b.append(text(70, y, title, 24, col, anchor="start"))
        y += 40
        for i, (ic, name) in enumerate(items):
            cx = 140 + (i % 7) * 220; cy = y + 60 + (i // 7) * 150
            b.append(f"<g filter='url(#glow)'><rect x='{cx-48}' y='{cy-48}' width='96' height='96' rx='28' fill='{col}' opacity='0.18' stroke='{col}' stroke-width='3'/></g>")
            b.append(text(cx, cy + 18, ic, 50))
            b.append(text(cx, cy + 82, name, 19, C['text'], weight="normal"))
        y += 60 + ((len(items) - 1) // 7 + 1) * 150
    save("buffs", svg(W, H, "".join(b)))

# ---------- 4. storyboard ----------
def panel(x, y, w, h, title, content):
    return (f"<g><rect x='{x}' y='{y}' width='{w}' height='{h}' rx='22' fill='{C['bg0']}' stroke='{C['sub']}' stroke-opacity='0.35' stroke-width='2'/>"
            f"<svg x='{x}' y='{y}' width='{w}' height='{h}' viewBox='0 0 {w} {h}' overflow='hidden'>{content}</svg>"
            + text(x + 24, y + 46, title, 26, C['text'], anchor="start") + "</g>")

def sheet_storyboard():
    W, H = 1600, 1000
    pw, ph = 760, 430
    b = [text(W/2, 62, "Раскадровка смешных моментов (материал для клипов)", 40)]
    # 1 ceiling crush
    fl = 380
    c1 = [court(20, 740, fl, 70, [(380, 120)]),
          f"<polygon points='430,70 690,70 670,140 450,150' fill='#2B3560' stroke='{C['cyan']}' stroke-width='3' filter='url(#glow)'/>",
          f"<path d='M470,70 l20,25 l-15,20 M600,70 l-10,30 l20,20' stroke='white' stroke-width='3' opacity='0.6' fill='none'/>",
          f"<path d='M560,160 l0,40 M520,165 l-10,35 M600,165 l10,35' stroke='white' stroke-width='4' opacity='0.5' stroke-linecap='round'/>",
          blob(560, fl, 70, C['mag'], "scared", 1.0, 1.0),
          blob(180, fl, 60, C['cyan'], "smug", 1.0, 1.0, look=1), limb(220, fl - 50, 290, fl - 150, C['cyan'], -20, "fist", 9),
          text(380, 420, "1. «Пробить потолок» → кусок падает и давит соперника в блин", 20, C['sub'], weight="normal")]
    b.append(panel(30, 90, pw, ph, "Раздавил!", "".join(c1)))
    # 2 UFO
    c2 = [court(20, 740, fl, 70, [(380, 120)]), stars(760, 400, 25, 7),
          f"<g filter='url(#glow)'><ellipse cx='520' cy='110' rx='80' ry='22' fill='#3a3f5a' stroke='{C['lime']}' stroke-width='3'/><ellipse cx='520' cy='95' rx='36' ry='24' fill='{C['lime']}' opacity='0.5'/></g>",
          f"<path d='M500,135 Q470,220 230,300' stroke='{C['danger']}' stroke-width='4' fill='none' stroke-dasharray='10 8' filter='url(#glow)'/>",
          f"<g transform='rotate(150 240 300)'><rect x='225' y='292' width='40' height='16' rx='8' fill='{C['danger']}' filter='url(#glow)'/></g>",
          burst(560, 330, 50, C['orange']), blob(200, fl, 60, C['cyan'], "scared", 0.9, 1.25, look=1),
          blob(580, fl, 55, C['mag'], "dead", 1.5, 0.4),
          text(380, 420, "2. Событие «НЛО»: ракеты бьют по всем, хаос для обеих команд", 20, C['sub'], weight="normal")]
    b.append(panel(810, 90, pw, ph, "НЛО!", "".join(c2)))
    # 3 upside down
    c3 = [f"<g transform='rotate(180 380 225)'>", court(20, 740, fl, 70, [(380, 120)]),
          blob(170, fl, 60, C['cyan'], "scared", 1.0, 1.0), blob(590, fl, 60, C['mag'], "happy", 1.0, 1.0),
          ball(330, 200, 26), "</g>",
          f"<path d='M640,170 a70,70 0 1,1 -40,-60' stroke='{C['ball']}' stroke-width='5' fill='none' filter='url(#glow)'/>",
          f"<polygon points='596,96 618,118 590,124' fill='{C['ball']}'/>",
          text(380, 420, "3. «Вверх ногами»: экран перевернулся, управление прежнее — мозг ломается", 20, C['sub'], weight="normal")]
    b.append(panel(30, 545, pw, ph, "Вверх ногами", "".join(c3)))
    # 4 giant + portal
    c4 = [court(20, 740, fl, 70, [(380, 90)]),
          blob(170, fl, 150, C['cyan'], "smug", 1.0, 1.0, look=1),
          blob(600, fl, 50, C['mag'], "scared", 1.0, 1.0, look=-1),
          f"<ellipse cx='470' cy='160' rx='22' ry='60' fill='none' stroke='{C['buff']}' stroke-width='8' filter='url(#glowBig)'/>",
          f"<ellipse cx='650' cy='230' rx='22' ry='60' fill='none' stroke='{C['buff']}' stroke-width='8' filter='url(#glowBig)'/>",
          ball(620, 300, 26, trail=(-4, -14)),
          text(380, 420, "4. «Гигант ×2» + «Портал»: мяч уходит в портал и падает прямо за спину", 20, C['sub'], weight="normal")]
    b.append(panel(810, 545, pw, ph, "Гигант и портал", "".join(c4)))
    save("storyboard", svg(W, H, "".join(b)))

# ---------- 5. multi-team ----------
def sheet_multiteam():
    W, H = 1600, 800
    floor = 650; ceil = 150
    b = [stars(W, H, 50), text(W/2, 62, "3 команды: зоны + жизни", 42),
         text(W/2, 100, "мяч упал в твою зону — минус жизнь · без жизней команда выбывает, зоны пересобираются", 22, C['sub'], weight="normal"),
         court(60, 1540, floor, ceil, [(553, 200), (1047, 200)])]
    zones = [(60, 553, C['cyan'], "♥♥♥"), (553, 1047, C['lime'], "♥♡♡"), (1047, 1540, C['mag'], "♥♥♡")]
    for x0, x1, col, hearts in zones:
        b.append(f"<rect x='{x0+6}' y='{floor-6}' width='{x1-x0-12}' height='8' fill='{col}' opacity='0.8' filter='url(#glow)'/>")
        b.append(text((x0+x1)/2, 190, hearts, 40, col))
    b.append(blob(220, floor, 60, C['cyan'], "happy", look=1)); b.append(blob(390, floor, 60, C['cyan'], "angry", 0.85, 1.2, look=1))
    b.append(blob(800, floor, 60, C['lime'], "scared", look=-1))
    b.append(blob(1200, floor, 60, C['mag'], "smug", look=-1)); b.append(blob(1380, floor, 60, C['mag'], "happy", look=-1))
    b.append(ball(880, 420, 30, trail=(-24, -12)))
    b.append(text(800, 750, "в командах 2 · 1 · 2 игрока — состав может быть любым", 22, C['sub'], weight="normal"))
    save("multi-team", svg(W, H, "".join(b)))


# ---------- 6. jump sequence ----------
def sheet_jump():
    W, H = 1800, 1250
    b = [stars(W, H, 50), text(W/2, 64, "Прыжок: покадрово", 44),
         text(W/2, 102, "блоб по умолчанию — круглый шарик · тянется и сплющивается, сохраняя объём", 22, C['sub'], weight="normal")]
    fl = 640; R = 62
    b.append(f"<rect x='40' y='{fl}' width='{W-80}' height='4' fill='{C['cyan']}' opacity='0.7' filter='url(#glow)'/>")
    frames = [  # x, lift (bottom above floor), sx, sy, ground, mood, label
        (130, 0, 1.0, 1.0, True, "happy", "1. покой"),
        (380, 0, 1.3, 0.72, True, "angry", "2. присед"),
        (630, 25, 0.74, 1.38, False, "angry", "3. отрыв"),
        (880, 230, 0.9, 1.12, False, "happy", "4. подъём"),
        (1130, 330, 1.0, 1.0, False, "smug", "5. пик"),
        (1380, 200, 0.88, 1.15, False, "scared", "6. падение"),
        (1630, 0, 1.5, 0.58, True, "dead", "7. приземление"),
    ]
    pts = " ".join(f"{fx},{fl-lift-R*sy}" for fx, lift, sx, sy, g, m, l in frames)
    b.append(f"<polyline points='{pts}' fill='none' stroke='{C['ball']}' stroke-width='3' stroke-dasharray='8 10' opacity='0.45'/>")
    for fx, lift, sx, sy, g, mood, label in frames:
        mood = "happy" if mood == "dead" else mood
        b.append(blob(fx, fl - lift, R, C['cyan'], mood, sx, sy, look=0.6, ground=g, floor_y=fl))
        b.append(text(fx, fl + 52, label, 22, C['text'], weight="normal"))
    b.append(dust(630, fl)); b.append(dust(1630, fl, 1.3))
    b.append(text(1630, fl + 84, "→ отскок и колыхание", 18, C['sub'], weight="normal"))
    for fx, lift in ((630, 25), (880, 230)):
        yb = fl - lift
        b.append(f"<path d='M{fx-22},{yb+18} l0,40 M{fx},{yb+14} l0,55 M{fx+22},{yb+18} l0,40' stroke='{C['cyan']}' stroke-width='4' opacity='0.35' stroke-linecap='round'/>")
    # row 2: hit in the air
    fl2 = 1150; R2 = 62; lift = 110
    b.append(text(60, 800, "УДАР МЯЧОМ В ПРЫЖКЕ", 24, C['mag'], anchor="start"))
    b.append(f"<rect x='40' y='{fl2}' width='{W-80}' height='4' fill='{C['mag']}' opacity='0.7' filter='url(#glow)'/>")
    def top_of(sx, sy, dent):
        hh = R2 * sy
        return fl2 - lift - 2 * hh + dent * hh * 2
    # 1. ball incoming from upper right
    t = top_of(1.0, 1.0, 0)
    b.append(blob(300, fl2 - lift, R2, C['mag'], "angry", 1.0, 1.0, look=0.5, ground=False, floor_y=fl2))
    b.append(ball(370, t - 70, 30, trail=(-22, 20)))
    # 2. contact: dent on top, blob squashed
    t = top_of(1.18, 0.85, 0.14)
    b.append(blob(900, fl2 - lift, R2, C['mag'], "scared", 1.18, 0.85, dent=0.14, ground=False, floor_y=fl2))
    b.append(f"<ellipse cx='900' cy='{t - 24}' rx='34' ry='25' fill='url(#ballG)' filter='url(#glowBig)'/>")
    b.append(f"<path d='M850,{t-10} l-22,-12 M950,{t-10} l22,-12 M900,{t-58} l0,-18' stroke='white' stroke-width='4' opacity='0.6' stroke-linecap='round'/>")
    # 3. ball flies off, blob wobbles
    t = top_of(0.92, 1.1, 0)
    b.append(blob(1500, fl2 - lift, R2, C['mag'], "smug", 0.92, 1.1, look=1, ground=False, floor_y=fl2))
    b.append(ball(1680, t - 40, 30, trail=(26, 20)))
    b.append(f"<path d='M1420,{t+40} q-18,14 0,28 M1580,{t+40} q18,14 0,28' stroke='{C['mag']}' stroke-width='4' fill='none' opacity='0.55'/>")
    for hx, label in ((300, "1. мяч летит на блоб"), (900, "2. касание: вмятина сверху"), (1500, "3. мяч отлетает, блоб колышется")):
        b.append(text(hx, fl2 + 52, label, 22, C['text'], weight="normal"))
    save("jump", svg(W, H, "".join(b)))

if __name__ == "__main__":
    for f in (sheet_jump, sheet_blobs, sheet_gameplay, sheet_buffs, sheet_storyboard, sheet_multiteam):
        f()
    print("ok")
