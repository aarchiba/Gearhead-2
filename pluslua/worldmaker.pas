program worldmaker;
	{ This program loads an image file and converts it to a series of 30x30 }
	{ maps. }
	{ The image should use indexed color, with each color value corresponding }
	{ to a GH terrain value. }
{
	GearHead2, a roguelike mecha CRPG
	Copyright (C) 2005 Joseph Hewitt

	This library is free software; you can redistribute it and/or modify it
	under the terms of the GNU Lesser General Public License as published by
	the Free Software Foundation; either version 2.1 of the License, or (at
	your option) any later version.

	The full text of the LGPL can be found in license.txt.

	This library is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
	General Public License for more details. 

	You should have received a copy of the GNU Lesser General Public License
	along with this library; if not, write to the Free Software Foundation,
	Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA 
}
{$LONGSTRINGS ON}


uses sdl,sdlutils,sdl_image,sdlgfx,locale,randmaps,gears,texutil;

const
	world_image = 'image/ghr.png';
	world_desig = 'EARTH';
	world_name = 'Earth';
	map_width = 30;

Function MapSegFileName( Longitude , Latitude: Integer ): String;
	{ Return a filename for this map segment. }
begin
	MapSegFileName := 'MAPS_' + world_desig + '_' + WideStr( Longitude , 2 ) + 'x' + WideStr( Latitude , 2 ) + '.txt';
end;

var
	Test_Image: PSDL_Surface;
	XMaps,YMaps,Longitude,Latitude,X,Y,X0,Y0,terr: LongInt;
	GB: GameBoardPtr;
	F: Text;

begin
	{ Graphics initialization handled by sdlgfx above. }

	GB := NewMap( map_width , map_width );

	Test_Image := img_load( world_image );
	if Test_Image <> Nil then begin
		{ We're in. Yay! Time to start chopping this image into maps. }
		XMaps := Test_Image^.w div map_width;
		YMaps := Test_Image^.h div map_width;

		{ First, create all the sub-maps and save them in the setting directory. }
		for Longitude := 1 to XMaps do begin
			for Latitude := 1 to YMaps do begin
				X0 := ( Longitude - 1 ) * map_width;
				Y0 := ( Latitude - 1 ) * map_width;
				for X := 1 to map_width do begin
					for Y := 1 to map_width do begin
						terr := SDL_GetPixel( Test_Image , X + X0 , Y + Y0 ) + 1;
						if ( terr < 1 ) or ( terr > NumTerr ) then terr := TERRAIN_TILEFLOOR;
						SetTerrain( GB , X , Y , terr );
					end;
				end;
				SavePredrawnMap( GB , MapSegFileName( Longitude , Latitude ) );
			end;
		end;

		{ Next, create an Atlast stub containing scenes for all the maps. }
		Assign( F , 'tmp_ATLAS_' + world_name + '.txt' );
		Rewrite( F );

		writeln( F , '% ATLAS file created automatically by worldmaker' );
		writeln( F , '% To add locations, find that cel and edit it. There must not' );
		writeln( F , '% be two scenes with the same world map coordinates.' );
		writeln( F , '' );

		writeln( F , 'World 200');
		writeln( F , '	name <' + world_name + '>');
		writeln( F , '	desig <' + world_desig + '>');
		writeln( F , '	MapWidth ' + BStr( XMaps ) );
		writeln( F , '	MapHeight ' + BStr( YMaps ) );
		writeln( F , '	WorldMapWidth ' + BStr( map_width ) );
		writeln( F , '' );

		{ Write the scenes. }
		for Longitude := 1 to XMaps do begin
			for Latitude := 1 to YMaps do begin
				writeln( F , 'Scene 0 3' );
				writeln( F , '	mapwidth ' + BStr( map_width ) );
				writeln( F , '	mapheight ' + BStr( map_width ) );
				writeln( F , '	name <' + world_desig + '_' + WideStr( Longitude , 2 ) + 'x' + WideStr( Latitude , 2 ) + '>' );
				writeln( F , '	WorldMapX ' + BStr( Longitude ) );
				writeln( F , '	WorldMapY ' + BStr( Latitude ) );
				writeln( F , '	world <' + world_desig + '>' );
				writeln( F , '	map <' + MapSegFileName( Longitude , Latitude ) + '>' );
				writeln( F , '	special <NOEXIT SHOWALL SOLO>' );
				writeln( F , '	habitat <EARTH.MNTNS>' );

				writeln( F , '' );
			end;
		end;

		Close( F );

	end else begin
		writeln( 'Test image failed.' );
	end;

	SDL_FreeSurface( Test_Image );
	DisposeMap( GB );
end.
