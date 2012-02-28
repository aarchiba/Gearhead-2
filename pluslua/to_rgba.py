import os.path
import re, random
import pygame
import pygame.surfarray as surfarray
surfarray.use_arraytype('numpy')
import numpy as np

def to_rgba(infile, outfile):
	surface = pygame.image.load(infile)
	palette = ([(i,i,i) for i in range(3,259,4)] +
				[(i,0,0) for i in range(3,259,4)] +
				[(i,i,0) for i in range(3,259,4)] +
				[(0,i,0) for i in range(3,259,4)])
	palette[0] = (0,0,255)

	s = pygame.surface.Surface(surface.get_size(), depth=8)
	s.fill(0)
	s.set_palette(palette)
	s.blit(surface,(0,0))
	palette = ([(i,i,i) for i in range(3,259,4)] +
				[(i,0,0) for i in range(3,259,4)] +
				[(0,0,i) for i in range(3,259,4)] +
				[(0,i,0) for i in range(3,259,4)])
	palette[0] = (0,0,255)
	s.set_palette(palette)
	s.set_colorkey(0)
	# Convert to 24-bit truecolor with alpha
	s2 = s.convert_alpha(pygame.surface.Surface((10,10),depth=24))

	pygame.image.save(s2, outfile)

if __name__=='__main__':
	import sys

	pygame.init()
	size = width, height = 100, 100
	screen = pygame.display.set_mode(size)

	for f in sys.argv[1:]:
		to_rgba(f,f)
