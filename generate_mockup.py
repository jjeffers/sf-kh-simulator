from PIL import Image, ImageDraw, ImageFont

# Canvas
width = 800
height = 600
img = Image.new('RGB', (width, height), color=(30, 30, 30))
d = ImageDraw.Draw(img)

# Panel background
d.rectangle([(100, 75), (700, 525)], fill=(50, 50, 50), outline=(100, 100, 100), width=2)

# Title
# Try to use a default font if available, else default load 
try:
    font_large = ImageFont.truetype("DejaVuSans-Bold.ttf", 24)
    font_medium = ImageFont.truetype("DejaVuSans.ttf", 18)
    font_small = ImageFont.truetype("DejaVuSans.ttf", 14)
except IOError:
    font_large = ImageFont.load_default()
    font_medium = ImageFont.load_default()
    font_small = ImageFont.load_default()

d.text((250, 100), "DAMAGE CONTROL (DCR)", fill=(255, 255, 255), font=font_large)

# Mocked list
d.rectangle([(120, 150), (680, 450)], fill=(40, 40, 40))

# Ship Element
d.text((130, 160), "TestShip (DCR: 3)", fill=(0, 255, 255), font=font_medium)
d.text((130, 185), "Budget Remaining: 3", fill=(200, 200, 200), font=font_small)

# System element
d.text((140, 220), "Hull (10/20)", fill=(255, 255, 255), font=font_medium)
# Slider
d.rectangle([(350, 225), (550, 235)], fill=(80, 80, 80))
d.rectangle([(350, 225), (355, 235)], fill=(200, 200, 200)) # Handle
d.text((570, 220), "0%", fill=(255, 255, 255), font=font_medium)

# Button
d.rectangle([(300, 470), (500, 510)], fill=(30, 150, 30))
d.text((320, 480), "EXECUTE REPAIRS", fill=(0, 0, 0), font=font_medium)

img.save('/home/jdjeffers/.gemini/antigravity/brain/0bf7e67c-a9f1-4166-b9e0-6f0b12032f04/repair_panel_mockup.png')
print("Saved")
