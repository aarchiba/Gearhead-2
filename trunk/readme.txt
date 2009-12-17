************************
***   GEARHEAD  II   ***
************************

Welcome to the modern age. In NT157, a group of terrorists caused massive
destruction on Earth by awakening the biomonster Typhon. 

GH2 is released under the terms of the LGPL; see license.txt for more details.

For help with the game you can visit either the GearHead wiki, or the forum:
  Wiki:   http://gearhead.chaosforge.org/wiki/
  Forum:  http://gearhead.chaosforge.org/forum/

To run the SDL version you need to have SDL, SDL_Image, SDL_ttf, and
OpenGL installed. The precompiled Windows releases come with all needed
dlls.

*********************
***   COMPILING   ***
*********************

First of all you need FreePascal, available from www.freepascal.org.
To compile with graphics on Windows you also need the Jedi-SDL package,
available from here: http://sourceforge.net/projects/jedi-sdl/

On Linux, the SDL units come with the fpc compiler. Lucky you. Make sure that
you have libsdl, libsdl_image, and libsdl_ttf installed if you plan to use the
graphics version.

The default graphics mode is OpenGL. The game may be compiled to run in a
terminal window by setting the -dASCII command line switch. The game may also
be compiled in a less resource-intensive 2D graphical interface by setting the
-dCUTE command line switch.


Just type "ppc386 gearhead" and the program should compile.
To get the ASCII version, type "ppc386 -dASCII gearhead".

If you get a blue screen and no graphics, try uncommenting Revert_Slower_Safer
in gearhead.cfg.

I hope you have fun with the program.

- Joseph Hewitt
pyrrho12@yahoo.ca
