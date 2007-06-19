Program maped;
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

{$DEFINE ASCII}
uses gears,locale,vidgfx;

Procedure MEDisplayMap( GB: GameBoardPtr; Pen_X,Pen_Y: Integer );
	{ Display the map. Display all tiles and the locations of map cells. }
	{ The Pen_X , Pen_Y position should be centered on the screen. }
begin


	DoFlip;
end;

Procedure ClearMap( GB: GameBoardPtr; Pen: Integer );
	{ Clear thee map using the requested pen terrain. }
var
	X,Y: Integer;
begin
	for X := 1 to GB^.MapWidth do begin
		for Y := 1 to GB^.MapHeight do begin
			SetTerrain( GB , X , Y , Pen );
		end;
	end;
end;

Procedure SaveMap( GB: GameBoardPtr; const FName: String );
	{ Save this map to disk using the provided filename. }
begin
	Assign( F , Series_Directory + FName );
	Rewrite( F );

	{ Width and height get written first. }
	writeln( F , GB^.MapWidth );
	writeln( F , GB^.MapHeight );

	{ Write the map data. This part should be easy. }
	WriteMap( GB^.Map , F );

	{ Write the cell data. This part may take a bit more work. }


	Close( F );

end;

Procedure EditMap( GB: GameBoardPtr; const FName: String );
	{ Edit the given map. Save it to disk if need be. }
var
	A: CHar;
	Pen,Palette,X,Y: Integer;
	Procedure RepositionCursor( D: Integer );
	begin
		if OnTheMap( GB , X + AngDir[ D , 1 ] , Y + AngDir[ D , 2 ] ) then begin
			X := X + AngDir[ D , 1 ];
			Y := Y + AngDir[ D , 2 ];
		end;
	end;
begin
	{ Initialize our tools. }
	Pen := 1;
	Palette := 1;
	X := 1;
	Y := 1;

	repeat
		MEDisplayMap( GB , X , Y );
		MapEditInfo( Pen , Palette , X , Y );
		A := RPGKey;

		if A = KeyMap[ KMC_North ].KCode then begin
			RepositionCursor( 6 );

		end else if A = KeyMap[ KMC_South ].KCode then begin
			RepositionCursor( 2 );

		end else if A = KeyMap[ KMC_West ].KCode then begin
			RepositionCursor( 4 );

		end else if A = KeyMap[ KMC_East ].KCode then begin
			RepositionCursor( 0 );

		end else if A = KeyMap[ KMC_NorthEast ].KCode then begin
			RepositionCursor( 7 );

		end else if A = KeyMap[ KMC_SouthWest ].KCode then begin
			RepositionCursor( 3 );

		end else if A = KeyMap[ KMC_NorthWest ].KCode then begin
			RepositionCursor( 5 );

		end else if A = KeyMap[ KMC_SouthEast ].KCode then begin
			RepositionCursor( 1 );

		end else if A = ']' then begin
			Pen := Pen + 1;
			if Pen > NumTerr then pen := 1;

		end else if A = '[' then begin
			Pen := Pen - 1;
			if Pen < 1 then pen := NumTerr;

		end else if A = ' ' then begin
			SetTerrain( GB ,[ X , Y , Pen );

		end else if A = 'S' then begin
			SaveMap( GB );

		end else if A = 'C' then begin
			ClearMap( GB , Pen );

		end;

	until A = 'Q';

	{ Get rid of the map. }
	DisposeMap( GB );
end;


begin


end.
