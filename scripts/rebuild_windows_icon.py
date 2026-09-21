from PIL import Image
from pathlib import Path

src = Path(r'D:\projects\gekychat_desktop\assets\icons\gold_no_text\1024x1024.png')
out_ico = Path(r'D:\projects\gekychat_desktop\windows\runner\resources\app_icon.ico')
out_tray = Path(r'D:\projects\gekychat_desktop\assets\icons\tray_icon.ico')
out_png = Path(r'D:\projects\gekychat_desktop\assets\icons\app_icon_taskbar.png')
backup = out_ico.with_suffix('.ico.bak')

img = Image.open(src).convert('RGBA')
pixels = img.load()
w, h = img.size
min_x, min_y, max_x, max_y = w, h, 0, 0
threshold = 28
for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        if a < 16:
            continue
        if (r + g + b) / 3 > threshold:
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)

if max_x <= min_x or max_y <= min_y:
    raise SystemExit('Could not find logo content to crop')

pad = int(max(max_x - min_x, max_y - min_y) * 0.04)
min_x = max(0, min_x - pad)
min_y = max(0, min_y - pad)
max_x = min(w - 1, max_x + pad)
max_y = min(h - 1, max_y + pad)
cropped = img.crop((min_x, min_y, max_x + 1, max_y + 1))
print(f'Cropped content box: {(min_x, min_y, max_x, max_y)} size={cropped.size}')


def make_square(content: Image.Image, size: int, fill_ratio: float = 0.94) -> Image.Image:
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 255))
    target = int(size * fill_ratio)
    c = content.copy()
    c.thumbnail((target, target), Image.Resampling.LANCZOS)
    ox = (size - c.width) // 2
    oy = (size - c.height) // 2
    canvas.paste(c, (ox, oy), c)
    return canvas


master = make_square(cropped, 1024, fill_ratio=0.94)
master.save(out_png)
print(f'Wrote {out_png}')

sizes = [16, 24, 32, 48, 64, 128, 256]
icons = [make_square(cropped, s, fill_ratio=0.94) for s in sizes]

if out_ico.exists() and not backup.exists():
    backup.write_bytes(out_ico.read_bytes())
    print(f'Backed up to {backup}')

icons[-1].save(
    out_ico,
    format='ICO',
    sizes=[(s, s) for s in sizes],
    append_images=icons[:-1],
)
print(f'Wrote {out_ico} ({out_ico.stat().st_size} bytes) sizes={sizes}')

tray_sizes = [16, 24, 32, 48, 64]
tray_icons = [make_square(cropped, s, fill_ratio=0.96) for s in tray_sizes]
tray_icons[-1].save(
    out_tray,
    format='ICO',
    sizes=[(s, s) for s in tray_sizes],
    append_images=tray_icons[:-1],
)
print(f'Wrote {out_tray} ({out_tray.stat().st_size} bytes)')
print('Done')
