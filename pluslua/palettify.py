import os.path
import re, random
import pygame
import pygame.surfarray as surfarray
surfarray.use_arraytype('numpy')
import numpy as np

def palettify(infile, outfile):
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
	pygame.image.save(s, outfile)
 

def palettify_bogus(infile, outfile):
	surface = pygame.image.load(infile).convert(24)
	a = surfarray.pixels3d(surface)

	realgreens = (a[...,0]==0) & (a[...,2]==0)
	realreds = (a[...,1]==0) & (a[...,2]==0)
	realyellows = (a[...,0]==a[...,1]) & (a[...,2]==0)
	realblues = (a[...,0]==0) & (a[...,1]==0) & (a[...,2]==255)

	blues = (a[...,2]>127)
	greens = (a[...,0]<a[...,1]//2)
	reds = (a[...,1]<a[...,0]//2)
	yellows = ~greens & ~reds

	print infile, np.sum(realgreens & ~greens), np.sum(realreds & ~reds), np.sum(realyellows & ~yellows & ~reds & ~greens), np.sum(realblues & ~blues), np.sum(~realreds & ~realgreens & ~realyellows & ~realblues)

	a[greens,0] = 0
	a[greens,2] = 0
	a[yellows,0] = a[yellows,0] + (a[yellows,1]-a[yellows,0])//2
	a[yellows,1] = a[yellows,0]
	a[yellows,2] = 0
	a[reds,1] = 0
	a[reds,2] = 0
	a[blues,0] = 0
	a[blues,1] = 0
	a[blues,2] = 255

	del a

	pygame.image.save(surface, outfile)

if __name__=='__main__':
	import sys

	pygame.init()
	size = width, height = 900, 700
	screen = pygame.display.set_mode(size)

	for f in sys.argv[1:]:
		palettify(f,f)
