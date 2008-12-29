unit cutemap;
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


interface

uses locale,sdl,math,gears,texutil,cutegfx;

const
	LoAlt = -3;
	HiAlt = 5;

	Num_Prop_Meshes = 13;

var
	tile_x,tile_y,tile_z: LongInt;	{ Tile where the mouse pointer is pointing. }
	origin_x,origin_y: Integer;	{ Tile which the camera is pointing at. }
	origin_d: Integer;		{ The camera angle; one of four. }


	Overlays,Underlays: Array [1..MaxMapWidth,1..MaxMapWidth,LoAlt..HiAlt] of Integer;

	Model_Map: Array [1..MaxMapWidth,1..MaxMapWidth,LoAlt..( HiAlt + 1 )] of GearPtr;

	Terrain_Sprite,Strong_Hit_Sprite,Weak_Hit_Sprite,Parry_Sprite,Miss_Sprite: SensibleSpritePtr;

	Focused_On_Mek: GearPtr;


Function SpriteColor( GB: GameBoardPtr; M: GearPtr ): String;

Procedure RenderMap( GB: GameBoardPtr );
Procedure FocusOn( Mek: GearPtr );

Procedure DisplayMiniMap( GB: GameBoardPtr );
Procedure IndicateTile( GB: GameBoardPtr; X , Y , Z: Integer );

Procedure ScrollMap( GB: GameBoardPtr );

Procedure ClearOverlays;
Function ProcessShotAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;
Function ProcessPointAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;

Procedure RenderWorldMap( GB: GameBoardPtr; PC: GearPtr; X0,Y0: Integer );

Procedure InitGraphicsForScene( GB: GameBoardPtr );


implementation

uses ghmecha,ghchars,gearutil,ability,ghprop,effects,narration,ui4gh;

const
	Strong_Hit_Sprite_Name = 'blast64.png';
	Weak_Hit_Sprite_Name = 'nodamage64.png';
	Parry_Sprite_Name = 'misc_parry.png';
	Miss_Sprite_Name = 'misc_miss.png';

	Default_Prop_Sprite_Name = 'prop_box_low.png';
	Items_Sprite_Name = 'default_items.png';
	Default_Wreckage = 1;
	Default_Dead_Thing = 5;

	WallBrown: TSDL_Color = ( R: 76; G: 64; B: 51 );
	DoorBlue: TSDL_Color = ( R: 0; G: 128; B: 128 );
	WallGray: TSDL_Color = ( R: 70; G: 70; B: 55 );		{ For the low wall. }
	SmokeGray: TSDL_Color = ( R: 155; G: 150; B: 150 );
	ToxicGreen: TSDL_Color = ( R: 50; G: 170; B: 15 );

	TT_OpenGround = 1;
	TT_Tree = 2;
	TT_Mountain = 3;
	TT_ForestFloor = 4;
	TT_Swamp = 5;
	TT_Pavement = 6;
	TT_Rubble = 7;
	TT_RoughGround = 8;
	TT_GenericWall = 9;
	TT_GenericFloor = 10;
	TT_Threshold = 11;
	TT_Carpet = 12;
	TT_WoodenFloor = 13;
	TT_WoodenWall = 14;
	TT_TileFloor = 15;
	TT_WreckageWall = 16;
	TT_GlassWall = 17;
	TT_Elevator = 18;
	TT_StairsDown = 19;
	TT_TrapDoor = 20;
	TT_Door = 21;
	{ Terrain texture 22 is open for expansion }
	TT_Water = 23;

var
	Mini_Map_Sprite,World_Terrain: SensibleSpritePtr;
	Current_Tileset: Integer;


Function SpriteName( M: GearPtr ): String;
	{ Locate the sprite name for this gear. If no sprite name is defined, }
	{ set the default sprite name for the gear type & store it as a string }
	{ attribute so we won't need to do this calculation later. }
const
	FORM_DEFAULT: Array [1..NumForm] of String = (
	'btr_buruburu.png','zoa_scylla.png','ghu_ultari.png',
	'ara_kojedo.png', 'aer_wraith.png', 'orn_wasp.png',
	'ger_harpy.png', 'aer_bluebird.png', 'gca_rover.png'
	);
	DefaultMaleSpriteName = 'cha_m_citizen.png';
	DefaultFemaleSpriteName = 'cha_f_citizen.png';
	DefaultMaleSpriteHead = 'cha_m_';
	DefaultFemaleSpriteHead = 'cha_f_';
var
	it: String;
	FList: SAttPtr;
begin
	it := SAttValue( M^.SA , 'SDL_SPRITE' );
	if it = '' then begin
		if M^.G = GG_Character then begin
			if NAttValue( M^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then begin
				it := DefaultMaleSpriteHead;
			end else begin
				it := DefaultFemaleSpriteHead;
			end;
			it := it + SAttValue( M^.SA , 'JOB' ) + '.*';
			FList := CreateFileList( Graphics_Directory + it );
			if FList <> Nil then begin
				it := SelectRandomSAtt( FList )^.Info;
				DisposeSAtt( FList );
			end else begin
				if NAttValue( M^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then begin
					it := DefaultMaleSpriteName;
				end else begin
					it := DefaultFemaleSpriteName;
				end;
			end;
		end else if ( M^.G = GG_Mecha ) and ( M^.S >= 0 ) and ( M^.S < NumForm ) then begin
			it := FORM_DEFAULT[ M^.S + 1 ];
		end else if M^.G = GG_Prop then begin
			it := Default_Prop_Sprite_Name;
		end else begin
			it := Items_Sprite_Name;
		end;
		SetSAtt( M^.SA , 'SDL_SPRITE <' + it + '>' );
	end;
	SpriteName := it;
end;

Function SpriteColor( GB: GameBoardPtr; M: GearPtr ): String;
	{ Determine the color string for this model. }
const
	NumSkinColor = 8;
	SkinColor: Array [0..NumSkinColor-1] of String = (
	'142 62 39','150 112 89','252 212 195','255 212 195','252 212 195',
	'252 212 195', '252 212 195', '142 62 39'
	);
	NumHairColor = 10;
	HairColor: Array [0..NumHairColor-1] of String = (
	'128 56 35','55 50 50','234 180 88','166 47 32','75 200 212',
	'75 212 100', '220 120 50', '170 20 150', '20 0 80', '123 63 0'
	);
var
	it: String;
	T: Integer;
	Team,Faction: GearPtr;
begin
	it := SAttValue( M^.SA , 'SDL_COLORS' );
	{ Props usually but not always have their own palette, so if no }
	{ color has been stored in SDL_COLORS assume no color is needed. }
	if ( it = '' ) and ( M^.G <> GG_Prop ) and ( M^.G <> GG_MetaTerrain ) and ( GB = Nil ) then begin
		if M^.G = GG_Character then begin
			it := '100 100 100';
			it := it + ' ' + SkinColor[ Random(NumSkinColor) ] + ' ' + HairColor[ Random(NumHairColor) ];
		end else begin
			it := '175 175 171 100 100 120 0 200 200';
		end;
		SetSAtt( M^.SA , 'SDL_COLORS <' + it + '>' );

	end else if ( it = '' ) and ( M^.G <> GG_Prop ) and ( M^.G <> GG_MetaTerrain ) then begin
		T := NAttValue( M^.NA , NAG_Location , NAS_Team );
		Team := LocateTeam( GB , T );
		if Team <> Nil then it := SAttValue( Team^.SA , 'SDL_COLORS' );

		if it = '' then begin
			if Team <> Nil then Faction := SeekFaction( GB^.Scene , NAttValue( Team^.NA , NAG_Personal , NAS_FactionID ) )
			else Faction := Nil;
			if Faction = Nil then Faction := SeekFaction( GB^.Scene , NAttValue( M^.NA , NAG_Personal , NAS_FactionID ) );
			if M^.G = GG_Character then begin
				if Faction <> Nil then it := SAttValue( Faction^.SA , 'chara_colors' );
				if it = '' then begin
					if T = NAV_DefPlayerTeam then begin
						it := '66 121 179';
					end else if AreEnemies( GB , T , NAV_DefPlayerTeam ) then begin
						it := '180 10 120';
					end else if AreAllies( GB , T , NAV_DefPlayerTeam ) then begin
						it := '150 150 150';
					end else begin
						it := '100 100 100';
					end;
				end;
				it := it + ' ' + SkinColor[ Random(NumSkinColor) ] + ' ' + HairColor[ Random(NumHairColor) ];
			end else begin
				if Faction <> Nil then it := SAttValue( Faction^.SA , 'mecha_colors' );
				if it = '' then begin
					if T = NAV_DefPlayerTeam then begin
						it := '66 121 179 210 215 80 205 25 0';
					end else if AreEnemies( GB , T , NAV_DefPlayerTeam ) then begin
						it := '103 3 45 166 47 32 244 216 28';
					end else if AreAllies( GB , T , NAV_DefPlayerTeam ) then begin
						it := '66 121 119 190 190 190 0 205 0';
					end else begin
						it := '175 175 171 100 100 120 0 200 200';
					end;
				end;
			end;
		end;
		SetSAtt( M^.SA , 'SDL_COLORS <' + it + '>' );
	end;
	SpriteColor := it;
end;

Procedure RenderMap( GB: GameBoardPtr );
	{ Render the location stored in G_Map, along with all items and characters on it. }
	{ Also save the position of the mouse pointer, in world coordinates. }
const
	Row_D: Array [0..3,0..1] of Integer = (
	(0,1),(-1,0),(0,-1),(1,0)
	);
	Column_D: Array [0..3,0..1] of Integer = (
	(1,0),(0,1),(-1,0),(0,-1)
	);
var
	X,Y,Z,X0,Y0,MaxR,MaxC,Row,Column,Terr: Integer;
	SX,SY: LongInt;
	Frame: Integer;
	M: GearPtr;
	MyDest: TSDL_Rect;
	Spr: SensibleSpritePtr;
begin
	{ How to find out the proper mouse location- while drawing each sprite, do a check with the }
	{ map coordinates. If we get a second match later on, that supercedes the previous match obviously, }
	{ since we're overwriting something anyways. Brilliance! }

	ClrScreen;

	{ Start by clearing the model map. }
	for X := 1 to GB^.Map_Width do begin
		for Y := 1 to GB^.Map_Height do begin
			for z := LoAlt to ( HiAlt + 1 ) do begin
				model_map[ X , Y , z ] := Nil;
			end;
		end;
	end;

	{ Fill out the model map with the largest models in each tile, and also the item map, wreckage map, }
	{ smoke map, and fire map. }


	{ Depending on the view direction, set the cursor. }
	{ 0 is normal rotation, each +1 rotates the map counterclockwise by 90 degrees. }
	if origin_d = 0 then begin
		X0 := 1;
		Y0 := 1;
		MaxR := GB^.MAP_Height;
		MaxC := GB^.MAP_Width;
	end else if origin_d = 1 then begin
		X0 := GB^.Map_Width;
		Y0 := 1;
		MaxR := GB^.MAP_Width;
		MaxC := GB^.MAP_Height;
	end else if origin_d = 2 then begin
		X0 := GB^.MAP_Width;
		Y0 := GB^.MAP_Height;
		MaxR := GB^.MAP_Height;
		MaxC := GB^.MAP_Width;
	end else begin
		X0 := 1;
		Y0 := GB^.MAP_Height;
		MaxR := GB^.MAP_Width;
		MaxC := GB^.MAP_Height;
	end;

	{ Go through the rows and columns of our screen display. }
	for Row := -7 to 7 do begin
		{ Draw the terrain for this row. }
		for Column := -8 to 8 do begin
			{ Calculate the map position for this row,column combo. }
			X := origin_x + Row_D[ origin_d , 0 ] * Row + Column_D[ origin_d , 0 ] * Column;
			Y := origin_y + Row_D[ origin_d , 1 ] * Row + Column_D[ origin_d , 1 ] * Column;

			if OnTheMap( GB , X , Y ) then begin
				MyDest.X := 380 + Column * 50;
				MyDest.Y := 200 + Row * 40;

				Terr := TileTerrain( GB , X , Y );
				case Terr of

				TERRAIN_WALL:	begin
						DrawSprite( Terrain_Sprite , MyDest , 9 );
						MyDest.Y := MyDest.Y - 20;
						DrawSprite( Terrain_Sprite , MyDest , 9 );
						end;
				TERRAIN_FLOOR:	DrawSprite( Terrain_Sprite , MyDest , 5 );
				else DrawSprite( Terrain_Sprite , MyDest , 0 );
				end;

				if ( Row = 0 ) and ( Column = 0 ) then begin
					MyDest.Y := MyDest.Y - 20;
					Spr := LocateSprite( 'c_btr_buruburu.png' , '66 121 119 190 190 190 0 205 0' , 50 , 120 );
					DrawSprite( Spr , MyDest , 0 );
				end;
			end;
		end;
	end;

	{ Do the tactics cursor. }
	if Tactics_Turn_In_Progess and ( Focused_On_Mek <> Nil ) then begin
		X := NAttValue( Focused_On_Mek^.NA , NAG_Location , NAS_X );
		Y := NAttValue( Focused_On_Mek^.NA , NAG_Location , NAS_Y );

	end;
end;


Procedure FocusOn( Mek: GearPtr );
	{ Focus on the provided mecha. }
begin
	if Mek <> Nil then begin
		origin_x := NAttValue( Mek^.NA , NAG_Location , NAS_X ) - 1;
		origin_y := NAttValue( Mek^.NA , NAG_Location , NAS_Y ) - 1;
	end;
	Focused_On_Mek := Mek;
end;

Procedure IndicateTile( GB: GameBoardPtr; X , Y , Z: Integer );
	{ Indicate the requested tile. }
begin
	ClearOverlays;
	if OnTheMap( GB , X , Y ) and ( Z >= LoAlt ) and ( Z <= HiAlt ) then begin
		origin_x := x - 1;
		origin_y := y - 1;
		Underlays[ X , Y , Z ] := 1;
	end;
end;

Procedure DisplayMiniMap( GB: GameBoardPtr );
	{ Draw the mini-map. }
const
	ZONE_MiniMap: TSDL_Rect = ( X:15; Y: 15; W: 300; H: 300 );
var
	MyDest: TSDL_Rect;
	X,Y: Integer;
	M: GearPtr;
begin
	ZONE_MiniMap.W := GB^.MAP_Width * 3;
	ZONE_MiniMap.H := GB^.MAP_Height * 3;
	SDL_FillRect( game_screen , @ZONE_MiniMap , SDL_MapRGBA( Game_Screen^.Format , 0 , 0 , 255 , 150 ) );

	for x := 1 to GB^.MAP_Width do begin
		for y := 1 to GB^.MAP_Height do begin
			MyDest.X := ZONE_MiniMap.X - 3 + X*3;
			MyDest.Y := ZONE_MiniMap.Y - 3 + Y*3;
			DrawSprite( Mini_Map_Sprite , MyDest , TileTerrain( GB , X , Y ) + 10 );
		end;
	end;

	M := GB^.Meks;
	while M <> Nil do begin
		if IsMasterGear( M ) and MekVisible( GB , M ) and GearActive( M ) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			MyDest.X := ZONE_MiniMap.X - 3 + X*3;
			MyDest.Y := ZONE_MiniMap.Y - 3 + Y*3;

			if AreAllies( GB , NAV_DefPlayerTeam , NAttValue( M^.NA , NAG_Location , NAS_Team ) ) then begin
				DrawSprite( Mini_Map_Sprite , MyDest , 5 + ( Animation_Phase div 5 mod 2 ) );
			end else if AreEnemies( GB , NAV_DefPlayerTeam , NAttValue( M^.NA , NAG_Location , NAS_Team ) ) then begin
				DrawSprite( Mini_Map_Sprite , MyDest , 1 + ( Animation_Phase div 5 mod 2 ) );
			end else begin
				DrawSprite( Mini_Map_Sprite , MyDest , 3 + ( Animation_Phase div 5 mod 2 ) );
			end;

			DrawSprite( Mini_Map_Sprite , MyDest , 1 + ( Animation_Phase div 5 mod 2 ) );
		end;
		M := M^.Next;
	end;
end;

Procedure ScrollMap( GB: GameBoardPtr );
	{ Asjust the position of the map origin. }
	Procedure CheckOrigin;
		{ Make sure the origin position is legal. }
	begin
		if Origin_X < 1 then Origin_X := 1
		else if Origin_X > GB^.MAP_Width then Origin_X := GB^.MAP_Width;
		if Origin_Y < 1 then Origin_Y := 1
		else if Origin_Y > GB^.MAP_Height then Origin_Y := GB^.MAP_Height;
	end;
var
	L: Integer;
begin
{	if Mouse_X < 20 then begin
		Origin_X := Origin_X + FineDir[ ( Origin_D + Num_Rotation_Angles div 4 ) mod Num_Rotation_Angles , 1 ]/3;
		Origin_Y := Origin_Y + FineDir[ ( Origin_D + Num_Rotation_Angles div 4 ) mod Num_Rotation_Angles , 2 ]/3;
		checkorigin;
	END else if Mouse_X > ( screenwidth - 20 ) then begin
		Origin_X := Origin_X + FineDir[ ( Origin_D + Num_Rotation_Angles * 3 div 4 ) mod Num_Rotation_Angles , 1 ]/3;
		Origin_Y := Origin_Y + FineDir[ ( Origin_D + Num_Rotation_Angles * 3 div 4 ) mod Num_Rotation_Angles , 2 ]/3;
		checkorigin;
	end else if ( Mouse_Y < 20 ) then begin
		Origin_X := Origin_X + FineDir[ ( Origin_D + Num_Rotation_Angles div 2 ) mod Num_Rotation_Angles , 1 ]/3;
		Origin_Y := Origin_Y + FineDir[ ( Origin_D + Num_Rotation_Angles div 2 ) mod Num_Rotation_Angles , 2 ]/3;
		checkorigin;
	END else if ( Mouse_Y > ( screenheight - 20 ) ) then begin
		Origin_X := Origin_X + FineDir[ Origin_D , 1 ]/3;
		Origin_Y := Origin_Y + FineDir[ Origin_D , 2 ]/3;
		checkorigin;
	end;


	if origin_d <> origin_d_target then begin
		{ We're doing a smooth rotation. }
		L := origin_d_target - origin_d;

		if Minimal_Screen_Refresh then begin
			origin_d := origin_d_target;
		end else if L > Half_Rot_Angle then begin
			origin_d := ( origin_d + Num_Rotation_Angles - 1 ) mod Num_Rotation_Angles;
		end else if L > 0 then begin
			origin_d := ( origin_d + 1 ) mod Num_Rotation_Angles;
		end else if L < -Half_Rot_Angle then begin
			origin_d := ( origin_d + 1 ) mod Num_Rotation_Angles;
		end else begin
			origin_d := ( origin_d + Num_Rotation_Angles - 1 ) mod Num_Rotation_Angles;
		end;
	end else if ( RK_KeyState[ SDLK_Delete ] = 1 ) then begin
		origin_d := ( origin_d + 1 ) mod Num_Rotation_Angles;
		origin_d_target := origin_d;
	end else if ( RK_KeyState[ SDLK_Insert ] = 1 ) then begin
		origin_d := ( origin_d + Num_Rotation_Angles - 1 ) mod Num_Rotation_Angles;
		origin_d_target := origin_d;
	end;
	if ( RK_KeyState[ SDLK_PageUp ] = 1 ) and ( origin_zoom > LowZoom ) then begin
		origin_zoom := origin_zoom - 1;
	end else if ( RK_KeyState[ SDLK_PageDown ] = 1 ) and ( origin_zoom < HiZoom ) then begin
		origin_zoom := origin_zoom + 1;
	end;
}
end;


Procedure ClearOverlays;
	{ Erase all overlays currently on the screen. }
var
	X,Y,Z: Integer;
begin
	for X := 1 to MaxMapWidth do begin
		for y := 1 to MaxMapWidth do begin
			for Z := LoAlt to HiALt do begin
				Overlays[ X , Y , Z ] := 0;
				Underlays[ X , Y , Z ] := 0;
			end;
		end;
	end;
end;

Procedure AddOverlay( GB: GameBoardPtr; X , Y , Z , Tex: Integer );
	{ Add an overlay to the screen. }
begin
	if OnTheMap( GB , X , Y ) and ( Z >= LoAlt ) and ( Z <= HiAlt ) then begin
		Overlays[ X , Y , Z ] := Tex;
	end;
end;

Function ProcessShotAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;
	{ Process this shot. Return TRUE if the missile }
	{ is visible on the screen, FALSE otherwise. }
	{ V = Timer }
	{ Stat 1 , 2 , 3 -> X1 , Y1 , Z1 }
	{ Stat 4 , 5 , 6 -> X2 , Y2 , Z2 }
const
	X1 = 1;
	Y1 = 2;
	Z1 = 3;
	X2 = 4;
	Y2 = 5;
	Z2 = 6;
var
	P: Point;
begin
	{ Increase the counter, and find the next spot. }
	Inc( AnimOb^.V );
	P := SolveLine( AnimOb^.Stat[ X1 ] , AnimOb^.Stat[ Y1 ] , AnimOb^.Stat[ Z1 ] , AnimOb^.Stat[ X2 ] , AnimOb^.Stat[ Y2 ] , AnimOb^.Stat[ Z2 ] , AnimOb^.V );

	{ If this is the destination point, then we're done. }
	if ( P.X = AnimOb^.Stat[ X2 ] ) and ( P.Y = AnimOb^.Stat[ Y2 ] ) then begin
		RemoveGear( AnimList , ANimOb );
		P.X := 0;

	{ If this is not the destination point, draw the missile. }
	end else begin
		{Display bullet...}
		AddOverlay( GB , P.X , P.Y , P.Z , 1 );
	end;

	ProcessShotAnimation := True;
end;

Function ProcessPointAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;
	{ Process this effect. Return TRUE if the blast }
	{ is visible on the screen, FALSE otherwise. }
	{ V = Timer }
	{ Stat 1 , 2 , 3 -> X , Y , Z }
const
	X = 1;
	Y = 2;
	Z = 3;
var
	it: Boolean;
begin
	if AnimOb^.V < 10 then begin
		case AnimOb^.S of
		GS_DamagingHit: begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , 1 );

				end;
		GS_ArmorDefHit: begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] ,  2 );

				end;

		GS_Parry,GS_Block,GS_Intercept,GS_Resist:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] ,  3 );
				Inc( AnimOb^.V );
				end;

		GS_Dodge,GS_ECMDef:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , 4 );
				Inc( AnimOb^.V );
				end;

		GS_Backlash:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , 5 );

				end;
		GS_AreaAttack:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , 6 );

				end;
		end;


		{ Increment the counter. }
		Inc( AnimOb^.V );

		it := True;
	end else begin

		RemoveGear( AnimList , AnimOb );
		it := False;
	end;

	ProcessPointAnimation := it;
end;

Procedure RenderWorldMap( GB: GameBoardPtr; PC: GearPtr; X0,Y0: Integer );
	{ Render the world map. X0,Y0 is the center tile. }
var
	DX,DY,X,Y: Integer;
	MyDest: TSDL_Rect;
	MySprite: SensibleSpritePtr;
	M: GearPtr;
begin
	ClrZone( ZONE_WorldMap );
	MyDest.W := 64;
	MyDest.H := 64;
	{ First, render the terrain. }
	for DX := -2 to 2 do begin
		for DY := -2 to 2 do begin
			X := X0 + DX;
			Y := Y0 + DY;
			FixWorldCoords( GB^.Scene , X , Y );
			MyDest.X := ZONE_WorldMap.X + ( DX + 2 ) * 64;
			MyDest.Y := ZONE_WorldMap.Y + ( DY + 2 ) * 64;
			if OnTheMap( GB , X , Y ) then begin
				DrawSprite( World_Terrain , MyDest , TileTerrain( GB , X , Y ) - 1 );
			end;
		end;
	end;

	{ Next, draw any metaterrain that may be on the map. }
	M := GB^.Meks;
	while M <> Nil do begin
		if ( M^.G = GG_MetaTerrain ) and ( M^.Stat[ STAT_MetaVisibility ] = 0 ) and OnTheMap( GB , M ) then begin
			DX := NAttValue( M^.NA , NAG_Location , NAS_X ) - X0;
			if WorldWrapsX( GB^.Scene ) and ( DX < -2 ) then DX := DX + GB^.Map_Width;
			DY := NAttValue( M^.NA , NAG_Location , NAS_Y ) - Y0;
			if WorldWrapsY( GB^.Scene ) and ( DY < -2 ) then DY := DY + GB^.Map_Height;
			if ( DX >= -2 ) and ( DX <= 2 ) and ( DY >= -2 ) and ( DY <= 2 ) then begin
				MyDest.X := ZONE_WorldMap.X + ( DX + 2 ) * 64;
				MyDest.Y := ZONE_WorldMap.Y + ( DY + 2 ) * 64;
				MySprite := LocateSprite( SpriteName( M ) , SpriteColor( GB , M ) , 64 , 64 );
				DrawSprite( MySprite , MyDest , NAttValue( M^.NA , NAG_Display , NAS_PrimaryFrame ) );
			end;
		end;
		M := M^.Next;
	end;

	{ Finally, draw the little crosshair in the middle to indicate the party poistion. }
	if PC <> Nil then begin
		MyDest.X := ZONE_WorldMap.X + 128;
		MyDest.Y := ZONE_WorldMap.Y + 128;
		MySprite := LocateSprite( SpriteName( PC ) , SpriteColor( GB , PC ) , 64 , 64 );
		DrawSprite( MySprite , MyDest , 1 );
	end;
end;

Procedure InitGraphicsForScene( GB: GameBoardPtr );
	{ Initialize the graphics for this scene. Make sure the correct tilesets are loaded. }
var
	TileSet,BDNum: Integer;
begin

end;

initialization
	RPGKey;

	SDL_PumpEvents;
	SDL_GetMouseState( Mouse_X , Mouse_Y );


	tile_x := 1;
	tile_y := 1;

	origin_d := 0;

	Mini_Map_Sprite := LocateSprite( 'minimap.png' , 3 , 3 );
	World_Terrain := LocateSprite( 'world_terrain.png' , 64 , 64 );

	Terrain_Sprite := LocateSprite( 'cute_terrain.png' , 50 , 120 );

	Strong_Hit_Sprite := LocateSprite( Strong_Hit_Sprite_Name , 64, 64 );
	Weak_Hit_Sprite := LocateSprite( Weak_Hit_Sprite_Name , 64, 64 );
	Parry_Sprite := LocateSprite( Parry_Sprite_Name , 64, 64 );
	Miss_Sprite := LocateSprite( Miss_Sprite_Name , 64, 64 );

	ClearOverlays;
	Focused_On_Mek := Nil;


end.
