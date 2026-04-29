from PIL import Image
import sys

def process(file_in, file_out, r_mult, g_mult, b_mult):
    img = Image.open(file_in).convert("RGBA")
    data = img.getdata()
    new_data = []
    for item in data:
        r, g, b, a = item
        lum = max(r, g, b)
        
        out_r = int(lum * r_mult)
        out_g = int(lum * g_mult)
        out_b = int(lum * b_mult)
        
        new_alpha = min(255, int(lum * 1.5))
        
        new_data.append((min(255, out_r), min(255, out_g), min(255, out_b), new_alpha))
        
    img.putdata(new_data)
    img.save(file_out)

process(sys.argv[1], "fleet_friendly_upf.png", 0.2, 1.0, 1.0)
process(sys.argv[1], "fleet_enemy_upf.png", 1.0, 0.2, 0.2)
process(sys.argv[2], "fleet_friendly_sathar.png", 1.0, 0.2, 1.0)
process(sys.argv[2], "fleet_enemy_sathar.png", 1.0, 0.4, 0.1)

