from PIL import Image
from collections import Counter
from scipy.spatial import KDTree
import numpy as np
def hex_to_rgb(num):
    h = str(num)
    return int(h[0:4], 16), int(('0x' + h[4:6]), 16), int(('0x' + h[6:8]), 16)
def rgb_to_hex(num):
    h = str(num)
    return int(h[0:4], 16), int(('0x' + h[4:6]), 16), int(('0x' + h[6:8]), 16)
filename = input("What's the image name? ")
new_w, new_h = map(int, input("What's the new height x width? Like 28 28. ").split(' '))
palette_hex = ['0x000000', '0x2121FF', '0xFF0000', '0xFFB7AE', '0xDE9751', '0xFFB751', '0xFFFF00', '0x00FF00', '0x47B7AE', '0x00FFFF', '0xDEDEFF', '0x47B7FF','0xFFB7FF']
palette_rgb = [hex_to_rgb(color) for color in palette_hex]

pixel_tree = KDTree(palette_rgb)
im = Image.open("./sprite_originals/" + filename+ ".png") #Can be many different formats.
im = im.convert("RGBA")
layer = Image.new('RGBA',(new_w, new_h), (0,0,0,0))
layer.paste(im, (0, 0))
im = layer
#im = im.resize((new_w, new_h),Image.ANTIALIAS) # regular resize
pix = im.load()
pix_freqs = Counter([pix[x, y] for x in range(im.size[0]) for y in range(im.size[1])])
pix_freqs_sorted = sorted(pix_freqs.items(), key=lambda x: x[1])
pix_freqs_sorted.reverse()
print(pix)
outImg = Image.new('RGB', im.size, color='white')
outFile = open("./sprite_bytes/" + filename + '.txt', 'w')
hexFile = open("./sprite_bytes/" + filename + "_hex" + '.txt', 'w')
i = 0
for y in range(im.size[1]):
    col = 0
    hexFile.write("16'h")
    outFile.write("16'b")
    for x in range(im.size[0]):
        pixel = im.getpixel((x,y))
        print(pixel)
        if(pixel[3] < 100):
            outImg.putpixel((x,y), palette_rgb[0])
            outFile.write("0")
            hexFile.write('0')
            print(i)
        else:
            index = pixel_tree.query(pixel[:3])[1]
            outImg.putpixel((x,y), palette_rgb[index])
            num_of_bits = 4;
            scale = 16
            hex_data = hex(index)
            binary_string = bin(int(hex_data, scale))[2:].zfill(num_of_bits)
            outFile.write("%s" %str(1))
            hexFile.write("%x" %(index))
        if(col == 15):
            if(y == im.size[1] - 1):
                outFile.write("\n")
                hexFile.write("\n")
            else:
                outFile.write(",\n")
                hexFile.write(",\n")
        col += 1
        i += 1
outFile.close()
outImg.save("./sprite_converted/" + filename + ".png" )