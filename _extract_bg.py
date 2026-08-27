import re, io
from PIL import Image

c = open(r'firmware/dietai-firmware/src/pet_tiles.h', encoding='utf-8').read()
# 提取第一个帧 pet_normal_frame_0 的字节
m = re.search(r'pet_normal_frame_0\[\d+\][^\{]*\{(.*?)\};', c, re.S)
body = m.group(1)
d = bytes(int(b, 16) for b in re.findall(r'(?<![0-9A-Fa-f])0x([0-9A-Fa-f]{2})', body))
print('frame0 bytes:', len(d), 'head:', d[:8].hex())

img = Image.open(io.BytesIO(d)).convert('RGB')
print('size:', img.size)
for p in [(0, 0), (185, 0), (0, 185), (185, 185), (93, 93), (10, 10), (93, 5)]:
    r, g, b = img.getpixel(p)
    rgb565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
    print(p, (r, g, b), hex(rgb565))
