# 生成 Jin Notes App 图标：python3 tools/make_icon.py <输出目录>
import math, sys
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # 超采样后缩到 1024
def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

def background(c1, c2):
    # 对角线渐变（左上 -> 右下）
    small = Image.new("L", (256, 256))
    small.putdata([int((x + y) / 2) for y in range(256) for x in range(256)])
    grad = small.resize((S, S), Image.BILINEAR)
    base = Image.new("RGB", (S, S), c1)
    top = Image.new("RGB", (S, S), c2)
    return Image.composite(top, base, grad)

def card_layer(box, radius, fill, angle, shadow=None):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if shadow:
        sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([box[0], box[1]+60, box[2], box[3]+60], radius, fill=shadow)
        sh = sh.filter(ImageFilter.GaussianBlur(90))
        layer = Image.alpha_composite(layer, sh)
        d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box, radius, fill=fill)
    cx, cy = (box[0]+box[2])/2, (box[1]+box[3])/2
    return layer.rotate(angle, resample=Image.BICUBIC, center=(cx, cy)), d

def sparkle(d, cx, cy, R, fill):
    pts = []
    for i in range(360):
        t = math.radians(i)
        x = R * (math.cos(t) ** 3)
        y = R * (math.sin(t) ** 3)
        pts.append((cx + x, cy + y))
    d.polygon(pts, fill=fill)

def make(c1, c2, card_back, card_front, line_color, accent_line, spark, out):
    img = background(c1, c2).convert("RGBA")

    # 后面一张卡片（微微倾斜，半透明）
    back, _ = card_layer((1270, 1050, 3070, 3150), 260, card_back, 9)
    img = Image.alpha_composite(img, back)

    # 前面的主卡片
    box = (1120, 1250, 3020, 3350)
    front = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([box[0], box[1]+90, box[2], box[3]+90], 260, fill=(0, 40, 30, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(110))
    front = Image.alpha_composite(front, sh)
    d = ImageDraw.Draw(front)
    d.rounded_rectangle(box, 260, fill=card_front)

    # 卡片上的“文字行”：第一行是主题色（像 #标签），其余是灰线
    x0 = box[0] + 300
    lh = 170
    d.rounded_rectangle([x0, 1700, x0 + 620, 1700 + lh], lh/2, fill=accent_line)
    for i, w in enumerate([1300, 1300, 900]):
        y = 2150 + i * 380
        d.rounded_rectangle([x0, y, x0 + w, y + lh], lh/2, fill=line_color)
    front = front.rotate(-4, resample=Image.BICUBIC, center=((box[0]+box[2])/2, (box[1]+box[3])/2))
    img = Image.alpha_composite(img, front)

    # 灵感火花：右上角一大一小两颗星芒
    d = ImageDraw.Draw(img)
    sparkle(d, 3080, 1060, 500, spark)
    sparkle(d, 3500, 1620, 200, spark)

    img = img.convert("RGB").resize((1024, 1024), Image.LANCZOS)
    img.save(out)

out_dir = sys.argv[1]
# 浅色版
make(c1=(52, 211, 153), c2=(5, 150, 105),
     card_back=(255, 255, 255, 110), card_front=(255, 255, 255, 255),
     line_color=(203, 213, 225, 255), accent_line=(16, 185, 129, 255),
     spark=(255, 214, 102, 255), out=f"{out_dir}/icon-1024.png")
# 深色版（iOS 18 深色主屏图标）
make(c1=(24, 32, 38), c2=(10, 14, 18),
     card_back=(52, 211, 153, 60), card_front=(38, 48, 56, 255),
     line_color=(75, 90, 102, 255), accent_line=(52, 211, 153, 255),
     spark=(255, 214, 102, 255), out=f"{out_dir}/icon-1024-dark.png")
