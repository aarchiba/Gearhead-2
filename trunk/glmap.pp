unit glmap;
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

uses locale,sdl,gl,glu,glgfx,math,gears,texutil;

const
	Num_Terrain_Textures = 100;
	Num_Bitz_Textures = 25;
	Num_Building_Textures = 50;

	Num_Rotation_Angles = 40;
{	Num_Rotation_Angles = 8;}

	LoAlt = -3;
	HiAlt = 5;

	Num_Prop_Meshes = 9;

var
	tile_x,tile_y,tile_z: LongInt;	{ Tile where the mouse pointer is pointing. }
	origin_x,origin_y: GLFloat;	{ Tile which the camera is pointing at. }
	origin_zoom,origin_d: Integer;

	origin_d_target: Integer;	{ For non-instantaneous camera turns. }

	TerrTex: Array [1..Num_Terrain_Textures] of GLUInt;
	BitzTex: Array [1..Num_Bitz_Textures] of GLUInt;
	BuildingTex: Array [1..Num_Building_Textures] of GLUInt;
	SpaceTex: GLUInt;

	Overlays,Underlays: Array [1..MaxMapWidth,1..MaxMapWidth,LoAlt..HiAlt] of GLUInt;

	FineDir: Array [0..(Num_Rotation_Angles-1),1..2] of glFloat;
	DirOffset: Array [0..(Num_Rotation_Angles-1)] of Byte;

	Model_Map: Array [1..MaxMapWidth,1..MaxMapWidth,LoAlt..( HiAlt + 1 )] of GearPtr;

	SkyTex: GLUInt;

	Strong_Hit_Sprite,Weak_Hit_Sprite,Parry_Sprite,Miss_Sprite: SensibleTexPtr;

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

uses ghmecha,ghchars,gearutil,ability,ghprop,effects,narration,ui4gh,gl_objreader;

const
	LowZoom = 3;
	HiZoom = 30;

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
	Camera_Crane_Height: Array [LowZoom..HiZoom] of GLFloat;
	Current_Tileset: Integer;
	Current_Backdrop: GLUInt;

Procedure DrawTree( Tree_Tex: Integer; H: GLFloat );
	{ Draw a tree with its base centered on the origin. }
begin
	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );

	glBindTexture(GL_TEXTURE_2D, TerrTex[ Tree_Tex ] );
	glEnable( GL_Texture_2D );

	glEnable( GL_ALPHA_TEST );
	glAlphaFunc( GL_Equal , 1.0 );

	glbegin( GL_QUADS );

	glNormal3i( 0 , 1 , 0 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( -0.15 , 0 , 0.0 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( -0.15 , H , 0.0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 0.15 , H , 0.0 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 0.15 , 0 , 0.0 );

	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 0 , 0 , -0.15 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 0 , H , -0.15 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 0 , H , 0.15 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0 , 0 , 0.15 );

	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( -0.10 , 0 , -0.10 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( -0.10 , H , -0.10 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 0.10 , H , 0.10 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0.10 , 0 , 0.10 );

	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 0.10 , 0 , -0.10 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 0.10 , H , -0.10 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( -0.10 , H , 0.10 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( -0.10 , 0 , 0.10 );

 	glEnd;

	glDisable( GL_Texture_2D );
end;

Procedure DrawFloor( Tex: Integer; Offset: GLFloat );
	{ Draw a floor. This is like a wall, but only one quad and it's }
	{ horizontal. }
begin
	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
	glBindTexture(GL_TEXTURE_2D, Tex );
	glEnable( GL_Texture_2D );

	glbegin( GL_QUADS );

	GLColor3F( 1.0 , 1.0 , 1.0 );

	glTexCoord2f( 0.0 , 0.0 );
	GLNormal3i( 0 , 1 , 0 );
	glVertex3f( 0 , Offset , 0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 1 , Offset , 0 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 1 , Offset , 1 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0 , Offset , 1 );

 	glEnd;

	glDisable( GL_Texture_2D );
end;

Procedure DrawGrid();
	{ Draw a grid. Actually, draw one empty square. Enough of them and they make a grid. }
begin
	glDisable( GL_Lighting );
	glEnable( GL_BLEND );

	glEnable( GL_ALPHA_TEST );
	glAlphaFunc( GL_Greater , 0.0 );


	glBegin( GL_QUADS );

	GLColor4ub( 0 , 128 , 200 , 128 );

	glVertex3f( 0.4 , 0 , 0.4 );
	glVertex3f( 0.6 , 0 , 0.4 );
	glVertex3f( 0.6 , 0 , 0.6 );
	glVertex3f( 0.4 , 0 , 0.6 );

 	glEnd;
	glEnable( GL_Lighting );
end;


Procedure DrawForest( N,X,Y: Integer );
	{ Draw a forest. }
var
	T: Integer;
	C: Integer;
const
	NumConfigurations = 10;
	Positions: Array [1..NumConfigurations + 2,1..2] of GLFloat = (
	(0.17,0.17),(0.50,0.67),(0.67,0.50),
	(0.17,0.50),(0.67,0.17),(0.67,0.67),
	(0.50,0.17),(0.17,0.17),(0.67,0.50),
	(0.50,0.67),(0.17,0.50),(0.50,0.17)
	);
begin
	DrawFloor( TerrTex[ TT_ForestFloor ] , 0 );
	C := ( X * 23 + Y * 17 ) mod NumConfigurations;
	for t := 1 to N do begin
		glPushMatrix();

		glTranslateD( Positions[ C + T , 1 ] , 0 , Positions[ C + T , 2 ] );
		DrawTree( TT_Tree , ( T + 3 ) / 10 );

		glPopMatrix();
	end;
end;

Procedure DrawBuilding( Style,Alt: Integer );
	{ Draw a new building in the requested style at the current model position. }
	{ Buildings are constructed as a pile of blocks. }
	{ Buildings 0 is the generic metaterrain building. }
	{ Buildings 1 through 4 are variants of the "short building" terrain. }
	{ Buildings 5 through 8 are variants of the "tall building" terrain. }
	{ Buildings 15 through 18 are variants of the "very short building" terrain. }
	{ Each "brick" must be 0.5 units tall. }
const
	Wide_Gutter = 0.1;
	WG_Complement = 1.0 - Wide_Gutter;
	Narrow_Gutter = 0.2;
	NG_Complement = 1.0 - Narrow_Gutter;

	Procedure DrawMCDBox( Tex: Integer );
		{ Draw a building component which Saint Proverbius of the RPGCodex described }
		{ as looking like one of those old foam hamburger boxes from McDonald's. }
		{ I'd like to think that it contains the McNinja burger. }
	const
		NumVerticies = 12;

		Verticies: Array [1.. NumVerticies*3 ] of GLFLoat = (
			Narrow_Gutter, 0, Narrow_Gutter, NG_Complement, 0, Narrow_Gutter, NG_Complement, 0, NG_Complement,	Narrow_Gutter, 0, NG_Complement,
			Wide_Gutter, 0.15, Wide_Gutter,	WG_Complement, 0.15, Wide_Gutter, WG_Complement, 0.15, WG_Complement,	Wide_Gutter, 0.15, WG_Complement,
			Narrow_Gutter, 0.51, Narrow_Gutter,  NG_Complement, 0.51, Narrow_Gutter,  NG_Complement, 0.51, NG_Complement,  Narrow_Gutter, 0.51, NG_Complement
		);

		TexCoords: Array [1.. NumVerticies*2 ] of GLFloat = (
			0,1,	1,1,	0,1,	1,1,
			0,0.8,	1,0.8,	0,0.8,	1,0.8,
			0,0,	1,0,	0,0,	1,0
		);
	begin
		glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
		glBindTexture(GL_TEXTURE_2D, BuildingTex[ Tex ] );
		glEnable( GL_Texture_2D );

		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);

		glVertexPointer( 3 , GL_Float , 0 , @Verticies );
		glTexCoordPointer( 2 , GL_Float , 0 , @TexCoords );
		glBegin( GL_QUADS );

		glNormal3i( 0 , 0 , -1 );

		glArrayElement( 0 );
		glArrayElement( 1 );
		glArrayElement( 5 );
		glArrayElement( 4 );

		glArrayElement( 4 );
		glArrayElement( 5 );
		glArrayElement( 9 );
		glArrayElement( 8 );

		glNormal3i( 1 , 0 , 0 );

		glArrayElement( 1 );
		glArrayElement( 2 );
		glArrayElement( 6 );
		glArrayElement( 5 );

		glArrayElement( 5 );
		glArrayElement( 6 );
		glArrayElement( 10 );
		glArrayElement( 9 );

		glNormal3i( 0 , 0 , 1 );

		glArrayElement( 2 );
		glArrayElement( 3 );
		glArrayElement( 7 );
		glArrayElement( 6 );

		glArrayElement( 6 );
		glArrayElement( 7 );
		glArrayElement( 11 );
		glArrayElement( 10 );

		glNormal3i( -1 , 0 , 0 );

		glArrayElement( 3 );
		glArrayElement( 0 );
		glArrayElement( 4 );
		glArrayElement( 7 );

		glArrayElement( 7 );
		glArrayElement( 4 );
		glArrayElement( 8 );
		glArrayElement( 11 );

		glEnd;

		glDisableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		glDisable( GL_Texture_2D );
	end;

	Procedure DrawBox( Tex: Integer; Width: GLFloat );
		{ Draw a building component which is just a simple box. }
		{ The WIDTH provided is the width of the gutter, not of the building. }
	const
		NumVerticies = 8;
		Verticies: Array [1.. NumVerticies*3 ] of GLFLoat = (
			0.1, 0, 0.1,		0.9, 0, 0.1,		0.9, 0, 0.9,		0.1, 0, 0.9,
			0.1, 0.51, 0.1,		0.9, 0.51, 0.1,		0.9, 0.51, 0.9,		0.1, 0.51, 0.9
		);
		TexCoords: Array [1.. NumVerticies*2 ] of GLFloat = (
			0,1,	1,1,	0,1,	1,1,
			0,0,	1,0,	0,0,	1,0
		);
	begin
		glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
		glBindTexture(GL_TEXTURE_2D, BuildingTex[ Tex ] );
		glEnable( GL_Texture_2D );

		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);

		{ Set the appropriate values in the array. }
		Verticies[ 1 ] := Width;
		Verticies[ 3 ] := Width;
		Verticies[ 4 ] := 1.0 - Width;
		Verticies[ 6 ] := Width;
		Verticies[ 7 ] := 1.0 - Width;
		Verticies[ 9 ] := 1.0 - Width;
		Verticies[ 10 ] := Width;
		Verticies[ 12 ] := 1.0 - Width;
		Verticies[ 13 ] := Width;
		Verticies[ 15 ] := Width;
		Verticies[ 16 ] := 1.0 - Width;
		Verticies[ 18 ] := Width;
		Verticies[ 19 ] := 1.0 - Width;
		Verticies[ 21 ] := 1.0 - Width;
		Verticies[ 22 ] := Width;
		Verticies[ 24 ] := 1.0 - Width;

		glVertexPointer( 3 , GL_Float , 0 , @Verticies );
		glTexCoordPointer( 2 , GL_Float , 0 , @TexCoords );
		glBegin( GL_QUADS );

		glNormal3i( 0 , 0 , -1 );

		glArrayElement( 0 );
		glArrayElement( 1 );
		glArrayElement( 5 );
		glArrayElement( 4 );

		glNormal3i( 1 , 0 , 0 );

		glArrayElement( 1 );
		glArrayElement( 2 );
		glArrayElement( 6 );
		glArrayElement( 5 );

		glNormal3i( 0 , 0 , 1 );

		glArrayElement( 2 );
		glArrayElement( 3 );
		glArrayElement( 7 );
		glArrayElement( 6 );

		glNormal3i( -1 , 0 , 0 );

		glArrayElement( 3 );
		glArrayElement( 0 );
		glArrayElement( 4 );
		glArrayElement( 7 );

		glEnd;

		glDisableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);

		glDisable( GL_Texture_2D );
	end;

	Procedure DrawWideBox( Tex: Integer );
		{ Draw a building component which is just a wide box. }
	begin
		DrawBox( Tex , Wide_Gutter );
	end;

	Procedure DrawNarrowBox( Tex: Integer );
		{ Draw a building component which is just a narrow box. }
	begin
		DrawBox( Tex , Narrow_Gutter );
	end;

	Procedure DrawFlatCap( Tex: Integer; Gutter: GLFloat );
		{ Draw a flat building cap. }
	begin
		glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
		glBindTexture(GL_TEXTURE_2D, BuildingTex[ Tex ] );
		glEnable( GL_Texture_2D );

		glbegin( GL_QUADS );

		GLNormal3i( 0 , 1 , 0 );
		glTexCoord2f( 0.0 , 0.0 );
		glVertex3f( Gutter , 0 , Gutter );
		glTexCoord2f( 1.0 , 0.0 );
		glVertex3f( 1.0 - Gutter , 0 , Gutter );
		glTexCoord2f( 1.0 , 1.0 );
		glVertex3f( 1.0 - Gutter , 0 , 1.0 - Gutter );
		glTexCoord2f( 0.0 , 1.0 );
		glVertex3f( Gutter , 0 , 1.0 - Gutter );

	 	glEnd;

		glDisable( GL_Texture_2D );
	end;

	Procedure DrawPointyCap( Tex: Integer; Gutter: GLFloat );
		{ Draw a pointy building cap. }
	begin
		glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
		glBindTexture(GL_TEXTURE_2D, BuildingTex[ Tex ] );
		glEnable( GL_Texture_2D );

		glbegin( GL_TRIANGLE_FAN );

		GLNormal3i( 0 , 1 , 0 );

		glTexCoord2f( 0.5 , 0.5 );
		glVertex3f( 0.5 , 0.15 , 0.5 );
		glTexCoord2f( 0.0 , 0.0 );
		glVertex3f( Gutter , 0 , Gutter );
		glTexCoord2f( 1.0 , 0.0 );
		glVertex3f( 1.0 - Gutter , 0 , Gutter );
		glTexCoord2f( 1.0 , 1.0 );
		glVertex3f( 1.0 - Gutter , 0 , 1.0 - Gutter );
		glTexCoord2f( 0.0 , 1.0 );
		glVertex3f( Gutter , 0 , 1.0 - Gutter );
		glTexCoord2f( 0.0 , 0.0 );
		glVertex3f( Gutter , 0 , Gutter );
	 	glEnd;

		glDisable( GL_Texture_2D );
	end;

	Procedure DrawPyramid( Tex: Integer );
		{ Draw a building component which is wide at the base but }
		{ narow at the top. Kind of like half a brontosaurus sideways. }
	const
		NumVerticies = 8;
		Verticies: Array [1.. NumVerticies*3 ] of GLFLoat = (
			Wide_Gutter, 0, Wide_Gutter,		WG_Complement, 0, Wide_Gutter,		WG_Complement, 0, WG_Complement,	Wide_Gutter, 0, WG_Complement,
			Narrow_Gutter, 0.51, Narrow_Gutter,	NG_Complement, 0.51, Narrow_Gutter,	NG_Complement, 0.51, NG_Complement,	Narrow_Gutter, 0.51, NG_Complement
		);
		TexCoords: Array [1.. NumVerticies*2 ] of GLFloat = (
			0,1,	1,1,	0,1,	1,1,
			0,0,	1,0,	0,0,	1,0
		);
	begin
		glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
		glBindTexture(GL_TEXTURE_2D, BuildingTex[ Tex ] );
		glEnable( GL_Texture_2D );

		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);

		glVertexPointer( 3 , GL_Float , 0 , @Verticies );
		glTexCoordPointer( 2 , GL_Float , 0 , @TexCoords );
		glBegin( GL_QUADS );

		glNormal3i( 0 , 0 , -1 );

		glArrayElement( 0 );
		glArrayElement( 1 );
		glArrayElement( 5 );
		glArrayElement( 4 );

		glNormal3i( 1 , 0 , 0 );

		glArrayElement( 1 );
		glArrayElement( 2 );
		glArrayElement( 6 );
		glArrayElement( 5 );

		glNormal3i( 0 , 0 , 1 );

		glArrayElement( 2 );
		glArrayElement( 3 );
		glArrayElement( 7 );
		glArrayElement( 6 );

		glNormal3i( -1 , 0 , 0 );

		glArrayElement( 3 );
		glArrayElement( 0 );
		glArrayElement( 4 );
		glArrayElement( 7 );

		glEnd;

		glDisableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);

		glDisable( GL_Texture_2D );
	end;

	Procedure DrawPark( Tex: Integer );
		{ Draw a park entrance. This is a forest with a border. }
	begin
		DrawWideBox( Tex );
		DrawForest( 4 , 5 , 5 );
	end;
const
	NumBuildingStyles = 20;

	LEVEL_MCDBOX = 1;
	LEVEL_WIDEBOX = 2;
	LEVEL_NARROWBOX = 3;
	LEVEL_PYRAMID = 4;
	LEVEL_FOREST = 5;

	CAP_NONE = 0;
	CAP_WIDEFLAT = 1;
	CAP_NARROWFLAT = 2;
	CAP_WIDEPOINTY = 3;
	CAP_NARROWPOINTY = 4;

	Level_Type: Array [0..NumBuildingStyles,1..4] of Integer = (
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX), 	{Generic Building}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX), 	{TLowBuilding 1}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX), 		{TLowBuilding 2}
		(LEVEL_NARROWBOX,LEVEL_NARROWBOX,LEVEL_NARROWBOX,LEVEL_NARROWBOX), 	{TLowBuilding 3}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX), 	{TLowBuilding 4}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX), 	{THighBuilding 1}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX),	{THighBuilding 2}
		(LEVEL_NARROWBOX,LEVEL_NARROWBOX,LEVEL_NARROWBOX,LEVEL_NARROWBOX), 	{THighBuilding 3}
		(LEVEL_WIDEBOX,LEVEL_PYRAMID,LEVEL_NARROWBOX,LEVEL_WIDEBOX), 	{THighBuilding 4}
		(LEVEL_PYRAMID,LEVEL_NARROWBOX,LEVEL_MCDBOX,LEVEL_WIDEBOX),	{SpacePort}
		(LEVEL_WIDEBOX,LEVEL_PYRAMID,LEVEL_NARROWBOX,LEVEL_MCDBOX),	{Hospital}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX),	{Garage}
		(LEVEL_NARROWBOX,LEVEL_NARROWBOX,LEVEL_NARROWBOX,LEVEL_NARROWBOX), 	{Department Store}
		(LEVEL_PYRAMID,LEVEL_NARROWBOX,LEVEL_NARROWBOX,LEVEL_NARROWBOX),	{Cavalier Club}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX),	{Silver Fortress}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX), 	{TVeryLowBuilding 1}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX), 		{TVeryLowBuilding 2}
		(LEVEL_NARROWBOX,LEVEL_NARROWBOX,LEVEL_NARROWBOX,LEVEL_NARROWBOX), 	{TVeryLowBuilding 3}
		(LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX,LEVEL_WIDEBOX), 	{TVeryLowBuilding 4}
		(LEVEL_WIDEBOX,LEVEL_PYRAMID,LEVEL_NARROWBOX,LEVEL_NARROWBOX),	{ Arena }
		(LEVEL_FOREST,LEVEL_FOREST,LEVEL_FOREST,LEVEL_FOREST)		{ Park }
	);
	Level_Texture: Array [0..NumBuildingStyles,1..4] of Integer = (
		(1,2,2,2),
		(6,7,7,7),(6,7,7,7),(6,7,7,7),(6,7,7,7),
		(6,7,7,7),(6,7,7,7),(6,7,7,7),(6,7,7,7),
		(9,21,8,8),(1,11,2,11),(12,13,13,13),(14,15,15,15),
		(17,17,17,17),(19,20,20,20),(6,7,7,7),(6,7,7,7),
		(6,7,7,7),(6,7,7,7),(22,20,20,20),(24,24,24,24)
	);
	Cap_Type: Array [0..NumBuildingStyles] of Integer = (
		CAP_WIDEFLAT,
		CAP_WIDEFLAT, CAP_WIDEFLAT, CAP_NARROWFLAT, CAP_WIDEFLAT,
		CAP_WIDEFLAT, CAP_WIDEFLAT, CAP_NARROWFLAT, CAP_NARROWFLAT,
		CAP_NARROWFLAT, CAP_NARROWFLAT, CAP_WIDEFLAT, CAP_NARROWFLAT,
		CAP_NARROWPOINTY,CAP_WIDEPOINTY, CAP_WIDEFLAT, CAP_WIDEFLAT,
		CAP_NARROWFLAT, CAP_WIDEFLAT, CAP_NARROWFLAT, CAP_None
	);
	Cap_Texture: Array [0..NumBuildingStyles] of Integer = (
		3,
		4, 5, 4, 4,
		4, 5, 4, 4,
		10, 3, 5, 16,
		18, 18, 4, 5,
		4, 4, 23, 3
	);
var
	T: Integer;
begin
	if Alt < 1 then Alt := 1
	else if Alt > 4 then Alt := 4;
	if ( Style < 0 ) or ( Style > NumBuildingStyles ) then Style := 0;

	glEnable( GL_NORMALIZE );
	for t := 1 to Alt do begin
		case Level_Type[ Style , t ] of
			LEVEL_MCDBOX:	DrawMCDBox( Level_Texture[ Style , t ] );
			LEVEL_WIDEBOX:	DrawWideBox( Level_Texture[ Style , t ] );
			LEVEL_NARROWBOX:	DrawNarrowBox( Level_Texture[ Style , t ] );
			LEVEL_PYRAMID:	DrawPyramid( Level_Texture[ Style , t ] );
			LEVEL_FOREST:	DrawPark( Level_Texture[ Style , t ] );
		end;
		glTranslated( 0 , 0.5 , 0 );
	end;
	case Cap_Type[ Style ] of
		CAP_WIDEFLAT:	DrawFlatCap( Cap_Texture[ Style ] , Wide_Gutter );
		CAP_NARROWFLAT:	DrawFlatCap( Cap_Texture[ Style ] , Narrow_Gutter );
		CAP_WIDEPOINTY:	DrawPointyCap( Cap_Texture[ Style ] , Wide_Gutter );
		CAP_NARROWPOINTY:	DrawPointyCap( Cap_Texture[ Style ] , Narrow_Gutter );
	end;

	glDisable( GL_NORMALIZE );
end;


Procedure DrawMountain( GB: GameboardPtr; X,Y,Tex: Integer );
	{ Draw a mountain. }
const
	Verticies: Array [1..51] of GLFloat = (
		0, 0, 0,	0.5, 0, 0,
		1, 0, 0,	1, 0, 0.5,
		1, 0, 1,	0.5 , 0, 1,
		0, 0, 1,	0, 0, 0.5,

		0, 0.5, 0,	0.5, 0.5, 0,
		1, 0.5, 0,	1, 0.5, 0.5,
		1, 0.5, 1,	0.5 , 0.5, 1,
		0, 0.5, 1,	0, 0.5, 0.5,
		0.5,0.5,0.5
	);
	TexCoords: Array [1..34] of GLFloat = (
		0,0,	0.5,0,
		1,0,	1,0.5,
		1,1,	0.5,1,
		0,1,	0,0.5,
		0.1,0.1,	0.5,0.1,
		0.9,0.1,	0.9,0.5,
		0.9,0.9,	0.5,0.9,
		0.1,0.9,	0.1,0.5,
		0.5,0.5
	);
	Function TileHeight( TX,TY: Integer ): GLFloat;
	begin
		if not OnTheMap( GB , TX , TY ) then begin
			TileHeight := 0;
		end else begin
			TileHeight := TerrMan[ TileTerrain( GB , TX , TY ) ].Altitude / 2;
		end;
	end;
var
	t: Integer;
begin
	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
	glBindTexture(GL_TEXTURE_2D, TerrTex[ Tex ] );
	glEnable( GL_Texture_2D );

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);

	Verticies[ 50 ] := TerrMan[ TileTerrain( GB , X , Y ) ].Altitude / 2;
	Verticies[ 29 ] := ( TileHeight( X , Y - 1 ) + Verticies[ 50 ] ) / 2;
	Verticies[ 35 ] := ( TileHeight( X + 1 , Y ) + Verticies[ 50 ] ) / 2;
	Verticies[ 41 ] := ( TileHeight( X , Y + 1 ) + Verticies[ 50 ] ) / 2;
	Verticies[ 47 ] := ( TileHeight( X - 1 , Y ) + Verticies[ 50 ] ) / 2;
	Verticies[ 50 ] := Verticies[ 50 ] + 0.15;
	Verticies[ 26 ] := ( Verticies[ 29 ] + Verticies[ 47 ] ) / 2;
	Verticies[ 32 ] := ( Verticies[ 29 ] + Verticies[ 35 ] ) / 2;
	Verticies[ 38 ] := ( Verticies[ 35 ] + Verticies[ 41 ] ) / 2;
	Verticies[ 44 ] := ( Verticies[ 41 ] + Verticies[ 47 ] ) / 2;

	glVertexPointer( 3 , GL_Float , 0 , @Verticies );
	glTexCoordPointer( 2 , GL_Float , 0 , @TexCoords );

	glBegin( GL_QUADS );

	glArrayElement( 0 );
	glArrayElement( 8 );
	glArrayElement( 9 );
	glArrayElement( 1 );

	glArrayElement( 9 );
	glArrayElement( 1 );
	glArrayElement( 2 );
	glArrayElement( 10 );

	glArrayElement( 2 );
	glArrayElement( 10 );
	glArrayElement( 11 );
	glArrayElement( 3 );

	glArrayElement( 11 );
	glArrayElement( 3 );
	glArrayElement( 4 );
	glArrayElement( 12 );

	glArrayElement( 4 );
	glArrayElement( 12 );
	glArrayElement( 13 );
	glArrayElement( 5 );

	glArrayElement( 13 );
	glArrayElement( 5 );
	glArrayElement( 6 );
	glArrayElement( 14 );

	glArrayElement( 6 );
	glArrayElement( 14 );
	glArrayElement( 15 );
	glArrayElement( 7 );

	glArrayElement( 15 );
	glArrayElement( 7 );
	glArrayElement( 0 );
	glArrayElement( 8 );

	glEnd;

	glBegin( GL_TRIANGLE_FAN );

	glArrayElement( 16 );
	glArrayElement( 8 );
	glArrayElement( 9 );
	glArrayElement( 10 );
	glArrayElement( 11 );
	glArrayElement( 12 );
	glArrayElement( 13 );
	glArrayElement( 14 );
	glArrayElement( 15 );
	glArrayElement( 8 );


	glEnd;

	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);

	glDisable( GL_Texture_2D );
end;

Procedure DrawModel( Tex: Integer; Width,Offset,Foot,Fade: GLFloat );
	{ Draw a model. This is like a floor, but facing the camera and vertical. }
	{ WIDTH is the size of the tile. }
	{ OFFSET is a distance closer to the camera; used to order the depth of models. }
	{ FOOT is the distance the model is off the ground. }
	{ FADE is the percentage of the model to hide. Used for fading out models. }
begin
	glEnable( GL_BLEND );
	GLColor3F( 1.0 , 1.0 , 1.0 );
	glPushMatrix();

	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
	glBindTexture(GL_TEXTURE_2D, Tex );
	glEnable( GL_Texture_2D );

	glTranslatef( 0.5 , 0 , 0.5 );
	glRotatef( -( ( origin_d + Num_Rotation_Angles div 4 ) mod Num_Rotation_Angles ) * ( 360 / Num_Rotation_Angles ) , 0 , 1 , 0 );
	glbegin( GL_QUADS );

	glTexCoord2f( 1.0 - Fade / 200 , 1.0 );
	GLNormal3f( 0 , 0 , 1 );
	glVertex3f( -( Width / 2 ) * ( 100 - Fade ) / 100 , Foot , Offset );
	glTexCoord2f( Fade / 200 , 1.0 );
	glVertex3f( ( Width / 2 ) * ( 100 - Fade ) / 100 , Foot , Offset );
	glTexCoord2f( Fade / 200 , 0.0 );
	glVertex3f( ( Width / 2 ) * ( 100 - Fade ) / 100 , Foot + Width , Offset );
	glTexCoord2f( 1.0 - Fade / 200 , 0.0 );
	glVertex3f( -( Width / 2 ) * ( 100 - Fade ) / 100 , Foot + Width , Offset );

 	glEnd;

	glDisable( GL_Texture_2D );
	glPopMatrix();

	glDisable( GL_BLEND );
end;

Procedure DrawWave( T,WP: Integer );
	{ Draw a wave at the current model coordinates in the current texture. }
begin
	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );

	glBindTexture(GL_TEXTURE_2D, TerrTex[ T ] );
	glEnable( GL_Texture_2D );

	glEnable( GL_BLEND );

	glbegin( GL_TRIANGLE_FAN );

	glColor4f( 1.0 , 1.0 , 1.0 , 0.5 );

	glTexCoord2f( 0.5 , 0.0 );
	GLNormal3i( 0 , 1 , 0 );
	glVertex3f( 0.5 , FineDir[ ( Animation_Phase ) mod Num_Rotation_Angles , 1 + Abs( WP ) mod 2 ] / 10 , 0.5 );

	glTexCoord2f( 0.0 , 0.95 );
	glVertex3i( 0 , 0 , 0 );

	glTexCoord2f( 1.0 , 0.95 );
	glVertex3i( 1 , 0 , 0 );

	glTexCoord2f( 0.0 , 0.95 );
	glVertex3i( 1 , 0 , 1 );

	glTexCoord2f( 1.0 , 0.95 );
	glVertex3i( 0 , 0 , 1 );

	glTexCoord2f( 0.0 , 0.95 );
	glVertex3i( 0 , 0 , 0 );

 	glEnd;
	glDisable( GL_BLEND );
	glDisable( GL_Texture_2D );
end;

Procedure DrawWall2( Tex: Integer; H: GLFloat; C: TSDL_COlor; ShowRoof: Boolean );
	{ Draw a wall at the current model coordinates in the current texture. }
	{ H is the height to draw the wall. }
begin
	if ShowRoof then begin
		glDisable( GL_Lighting );
		glbegin( GL_QUADS );
		GLNormal3i( 0 , 1 , 0 );
		GLColor3ub( C.R , C.G , C.B );
		glVertex3f( 0 , h + 0.001 , 0 );
		glVertex3f( 1 , h + 0.001 , 0 );
		glVertex3f( 1 , h + 0.001 , 1 );
		glVertex3f( 0 , h + 0.001 , 1 );
 		glEnd;
		glEnable( GL_Lighting );
	end;

	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );

	glBindTexture(GL_TEXTURE_2D, TerrTex[ Tex ] );
	glEnable( GL_Texture_2D );

	glEnable( GL_ALPHA_TEST );
	glAlphaFunc( GL_Equal , 1.0 );

	glbegin( GL_QUADS );
	GLColor3F( 1.0 , 1.0 , 1.0 );

	GLNormal3i( 0 , 0 , 0 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0 , 0 , 0 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 0 , h , 0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 1 , h , 0 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 1 , 0 , 0 );

	GLNormal3i( -1 , 0 , 0 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 0 , 0 , 0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 0 , h , 0 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 0 , h , 1 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0 , 0 , 1 );

	GLNormal3i( 1 , 0 , 0 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 1 , 0 , 0 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 1 , h , 0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 1 , h , 1 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 1 , 0 , 1 );

	GLNormal3i( 0 , 0 , 1 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 1 , 0 , 1 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 1 , h , 1 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 0 , h , 1 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0 , 0 , 1 );

 	glEnd;

	glDisable( GL_Texture_2D );

end;

Procedure SmartWall( Tex: Integer; C: TSDL_COlor );
	{ Draw the wall at the prefs-indicated height. }
begin
	if Use_Tall_Walls then begin
		DrawWall2( Tex , 0.75 , C , True );
	end else begin
		DrawWall2( Tex , 0.15 , C , True );
	end;
end;

Procedure DrawTransBox( Tex: Integer; F,H: GLFloat; C: TSDL_Color );
	{ Draw a wall-like frame at the current model coordinates in the }
	{ provided texture. H is the height to draw it. F is the height }
	{ of the foot, i.e. where to start drawing. }
begin
	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );

	glDisable( GL_Lighting );
	glEnable( GL_BLEND );

	glBindTexture(GL_TEXTURE_2D, Tex );
	glEnable( GL_Texture_2D );

	glEnable( GL_ALPHA_TEST );
	glAlphaFunc( GL_Greater , 0.0 );

	glbegin( GL_QUADS );
	GLColor4ub( C.R , C.G , C.B , 75 );

	GLNormal3i( 0 , 0 , 1 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0 , F , 0.2 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 0 , h , 0.2 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 1 , h , 0.2 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 1 , F , 0.2 );

	GLNormal3i( -1 , 0 , 0 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 0.2 , F , 0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 0.2 , h , 0 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 0.2 , h , 1 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0.2 , F , 1 );

	GLNormal3i( 1 , 0 , 0 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0.8 , F , 0 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 0.8 , h , 0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 0.8 , h , 1 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 0.8 , F , 1 );

	GLNormal3i( 0 , 0 , 1 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 1 , F , 0.8 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 1 , h , 0.8 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( 0 , h , 0.8 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0 , F , 0.8 );

 	glEnd;

	glDisable( GL_BLEND );
	glDisable( GL_Texture_2D );
end;

Procedure DrawStairs;
	{ Draw a set of stairs here. }
var
	T: Integer;
	Flash: GLFloat;
begin
	glDisable( GL_Lighting );
	glDisable( GL_Texture );
	Flash := FineDir[ ( Animation_Phase ) mod Num_Rotation_Angles , 1 ] / 20;

	for t := 1 to 5 do begin
		glPushMatrix();
		glTranslatef( T/10 , t/10 , 0 );
		glbegin( GL_QUADS );
		GLColor3F( 0.2 + T/10 + Flash , 0.3 + T/10 + Flash , 0.4 + T/10 + Flash );

		glVertex3f( 0.2 , 0 , 0.2 );
		glVertex3f( 0.2 , 0 , 0.8 );
		glVertex3f( 0.5 , 0 , 0.8 );
		glVertex3f( 0.5 , 0 , 0.2 );

		GLColor3F( T / 10 + Flash , 0.2 + T/10 + Flash , 0.3 + T/10 + Flash );
		glVertex3f( 0.2 , 0 , 0.2 );
		glVertex3f( 0.2 , -0.05 , 0.2 );
		glVertex3f( 0.5 , -0.05 , 0.2 );
		glVertex3f( 0.5 , 0 , 0.2 );

		glVertex3f( 0.2 , 0 , 0.2 );
		glVertex3f( 0.2 , -0.05 , 0.2 );
		glVertex3f( 0.2 , -0.05 , 0.8 );
		glVertex3f( 0.2 , 0 , 0.8 );

		glVertex3f( 0.2 , 0 , 0.8 );
		glVertex3f( 0.2 , -0.05 , 0.8 );
		glVertex3f( 0.5 , -0.05 , 0.8 );
		glVertex3f( 0.5 , 0 , 0.8 );

		glVertex3f( 0.5 , 0 , 0.2 );
		glVertex3f( 0.5 , -0.05 , 0.2 );
		glVertex3f( 0.5 , -0.05 , 0.8 );
		glVertex3f( 0.5 , 0 , 0.8 );

 		glEnd;
		glPopMatrix();
	end;
end;

Procedure DrawEncounter( M: GearPtr );
	{ Draw an encounter or "sensor blip" on the map. }
var
	T: Integer;
	Flash: GLFloat;
	R,G,B: GLFloat;
begin
	Flash := FineDir[ ( Animation_Phase ) mod Num_Rotation_Angles , 1 ] / 10;
	glMatrixMode( GL_MODELVIEW );

	if M^.Stat[ STAT_EncounterType ] = ENCOUNTER_Defense then begin
		R := 0.3;
		G := 0.0;
		B := 0.9;
	end else if M^.Stat[ STAT_EncounterType ] = ENCOUNTER_NonCombat then begin
		R := 0.6;
		G := 0.9;
		B := 0.0;
	end else begin
		R := 0.9;
		G := 0.5;
		B := 0.0;
	end;

	for t := 0 to 2 do begin
		glPushMatrix();
		glTranslatef( 0.5 , 0 , 0.5 );
		glRotatef( ( ( Animation_Phase + t * 100 ) mod 300 ) * 360 / 300 , 0 , 1 , 0 );

		glBegin( GL_QUADS );
		GLColor3F( R * 0.7 + Flash , G * 0.7 + Flash , B * 0.7 + Flash );
		glVertex3f( 0.0 , 0.0 , 0.0 );

		GLColor3F( R * 0.8 + Flash , G * 0.8 + Flash , B * 0.8 + Flash );
		glVertex3f( 0.5 , 0.25 , 0.0 );

		GLColor3F( R + Flash , G + Flash , B + Flash );
		glVertex3f( 0.0 , 0.5 , 0.0 );

		GLColor3F( R * 0.8 + Flash , G * 0.8 + Flash , B * 0.8 + Flash );
		glVertex3f( -0.5 , 0.25 , 0.0 );

		glEnd;
		glPopMatrix;
	end;
end;

Procedure DrawTacticsCursor;
	{ Draw the tactics cursor at the current drawing position. }
const
	tch = 0.6;
	tcb = 0.2;
	tcm = ( tch + tcb ) / 2;
begin
	{ ROtate to face the camera. }
	glDisable( GL_Lighting );
	glTranslatef( 0.5 , 0 , 0.5 );
	glRotatef( -( ( origin_d + Num_Rotation_Angles div 4 ) mod Num_Rotation_Angles ) * ( 360 / Num_Rotation_Angles ) , 0 , 1 , 0 );
	GLColor4F( 1.0, 0.2 + FineDir[ ( Animation_Phase ) mod Num_Rotation_Angles , 1 ] / 2, 0.0 + FineDir[ ( Animation_Phase ) mod Num_Rotation_Angles , 1 ] / 4, 0.0 );

	glBegin( GL_TRIANGLES );
	glVertex3f( -0.5 , tch , 0 );
	glVertex3f( -0.5 , tcb , 0 );
	glVertex3f( -0.4 , tcm , 0 );

	glVertex3f( 0.5 , tch , 0 );
	glVertex3f( 0.5 , tcb , 0 );
	glVertex3f( 0.4 , tcm , 0 );

	glEnd;
end;

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
	if ( it = '' ) and ( M^.G <> GG_Prop ) and ( M^.G <> GG_MetaTerrain ) then begin
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

Procedure DrawSkyBox( Tex: GLUInt );
	{ Draw the sky. }
begin
	GLColor4F( 1.0 , 1.0 , 1.0 , 0.0 );
	glBindTexture(GL_TEXTURE_2D, Tex );
	glEnable( GL_Texture_2D );

	glMatrixMode( GL_Projection );
	glLoadIdentity;
	glDisable( GL_Depth_Test );
	gluOrtho2d( 0.0 , screenwidth , 0.0 , screenheight );
	glMatrixMode( GL_ModelView );
	glLoadIdentity;

	glBegin(GL_Quads);
	glTexCoord2f( 0.0 + origin_d / Num_Rotation_Angles , 0.0 );
	glVertex2i( 0 , 0 );
	glTexCoord2f( 1.0 + origin_d / Num_Rotation_Angles , 0.0 );
	glVertex2i( screenwidth , 0 );
	glTexCoord2f( 1.0 + origin_d / Num_Rotation_Angles , 1.0 );
	glVertex2i( screenwidth , screenheight );
	glTexCoord2f( 0.0 + origin_d / Num_Rotation_Angles , 1.0 );
	glVertex2i( 0 , screenheight );
	glEnd;

	glDisable( GL_Texture_2D );
	glClear( GL_DEPTH_BUFFER_BIT );
	glFinish();
end;


Procedure DrawTerrain( GB: GameBoardPtr; T,X,Y: Integer );
	{ Draw the requested terrain type. }
begin
	{ Depending on the terrain, draw it. }
	Case T of
	1:	DrawFloor( TerrTex[ TT_OpenGround ] , 0 );		{ Open Ground }
	2:	DrawForest( 2 , X , Y );	{ Light Forest }
	3:	DrawForest( 3 , X , Y );	{ Heavy Forest }
	4:	{ WATER -> DO NOTHING };	{ L1 Water }
	5:	Begin				{ Rubble }
		DrawFloor( TerrTex[ TT_OpenGround ] , 0 );
		DrawFloor( TerrTex[ TT_Rubble ] , 0.01 );
		end;
	6:	DrawFloor( TerrTex[ TT_Pavement ] , 0 );		{ Pavement }
	7:	Begin				{ Swamp }
		DrawFloor( TerrTex[ TT_ForestFloor ] , 0 );
		DrawFloor( TerrTex[ TT_Swamp ] , 0.01 );
		end;
	8,9,10:	DrawMountain( GB , X , Y , TT_Mountain );	{ L1 Hill, L2 Hill, L3 Hill }
	11:	DrawFloor( TerrTex[ TT_RoughGround ] , 0 );		{ Rough Ground }
	12:	DrawWall2( TT_GenericWall , 0.45 , WallGray , True );	{Low Wall }
	13:	SmartWall( TT_GenericWall , WallBrown );	{ Generic Wall }
	14:	DrawFloor( TerrTex[ TT_GenericFloor ] , 0 );		{ Generic Floor }
	15:	DrawFloor( TerrTex[ TT_Threshold ] , 0 );		{ Threshold }
	16:	DrawFloor( TerrTex[ TT_Carpet ] , 0 );		{ Carpet }
	17,18:	{ WATER -> DO NOTHING };	{ L1 Water, L2 Water }
	19:	DrawFloor( TerrTex[ TT_WoodenFloor ] , 0 );		{ Wooden Floor }
	20:	SmartWall( TT_WoodenWall , WallBrown );	{ Wooden Wall }
	21:	DrawFloor( TerrTex[ TT_TileFloor ] , 0 );		{ Tile Floor }
	22:	begin				{ Wreckage }
		DrawFloor( TerrTex[ TT_GenericFloor ] , 0 );
		DrawFloor( TerrTex[ TT_Rubble ] , 0.05 );
		DrawWall2( TT_WreckageWall , 0.45 , WallBrown , False );
		end;
	23:	DrawGrid();	{ Space }
	24:	begin	{ Low Building }
		DrawFloor( TerrTex[ TT_OpenGround ] , 0 );
		DrawBuilding( ( ( X * 17 ) + ( Y * 71 ) ) mod 4 + 1 , 2 );
		end;
	25:	begin	{ Medium Building }
		DrawFloor( TerrTex[ TT_OpenGround ] , 0 );
		DrawBuilding( ( ( X * 79 ) + ( Y * 23 ) ) mod 4 + 5 , 3 );
		end;
	26:	SmartWall( TT_GlassWall , WallBrown );	{ Glass Wall }
	27:	begin	{ Very Low Building }
		DrawFloor( TerrTex[ TT_OpenGround ] , 0 );
		DrawBuilding( ( ( X * 79 ) + ( Y * 23 ) ) mod 4 + 15 , 1 );
		end;

	else DrawFloor( TerrTex[ TT_OpenGround ] , 0 );
	end;
end;

Procedure DrawPropMesh( P: GearPtr );
	{ Draw the needed mesh for this prop. }
begin
	{ Push the matrix, then translate to the center of the tile and }
	{ rotate to the correct angle. }
	glPushMatrix();
	glTranslatef( 0.5 , 0 , 0.5 );
	glRotatef( NAttValue( P^.NA , NAG_Location , NAS_D ) * 45 - 90 , 0 , 1 , 0 );

	glEnable( GL_Lighting );
	glEnable( GL_Light1 );
	glEnable( GL_Texture_2D );
	if NotDestroyed( P ) then begin
		glBindTexture(GL_TEXTURE_2D, SensibleTexID( SpriteName( P ) , '' , NAttValue( P^.NA , NAG_Display , NAS_PrimaryFrame ) ) );
	end else begin
		glBindTexture(GL_TEXTURE_2D, BitzTex[ 10 ] );
	end;
	glCallList( P^.Stat[ STAT_PropMesh ] );
	glDisable( GL_Lighting );
	glDisable( GL_Light1 );
	glDisable( GL_Texture_2D );

	glPopMatrix();
end;


Procedure SetLighting;
	{ Set the lighting and materials options. Yay. }
const
	LightPos: Array [1..4] of GLFloat = (
	0 , 100 , 0 , 1
	);
	LightDir: Array [1..4] of GLFloat = (
	0.5 , -0.5 , 0.5 , 1
	);
	mat_specular: Array [1..4] of GLFloat = ( 1.0, 1.0, 1.0, 1.0 );
	OutdoorAmbient: Array [1..4] of GLFloat = (
	0.7,0.7,0.7,1.0
	);
	LightAmbient: Array [1..4] of GLFloat = (
	0.9,0.9,0.9,1.0
	);
	LightDiffuse: Array [1..4] of GLFloat = (
	0.9,0.9,0.9,1.0
	);
	LightSpecular: Array [1..4] of GLFloat = (
	1.5,1.5,1.5,1.0
	);
begin
	glLightfv( GL_Light1 , GL_POSITION , @LightPos[1] );
	glLightfv( GL_Light1 , GL_SPOT_DIRECTION , @LightDir[1] );
	glLightModelf( GL_Light_Model_Local_Viewer , 1 );
	glLightModelfv( GL_Light_Model_Ambient , @OutDoorAmbient[1] );
	glLightfv( GL_Light1 , GL_AMBIENT , @LightAmbient[1] );
	glLightfv( GL_Light1 , GL_DIFFUSE , @LightDiffuse[1] );
	glLightfv( GL_Light1 , GL_SPECULAR , @LightSpecular[1] );
	glLightf( GL_Light1 , GL_QUADRATIC_ATTENUATION , 0.0008 );

	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, @mat_specular);
	glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, @mat_specular);
	glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, @mat_specular);

	glEnable( GL_Lighting );
	glEnable( GL_Light1 );
end;

Procedure DisplayName( M: GearPtr; X,Y,Z: GLFloat );
	{ Show a name for this model. }
var
	WinX,WinY,WinZ: SmallInt;
	Viewport: TViewPortArray;
	mvmatrix,projmatrix: T16DArray;
	MyDest: TSDL_Rect;
begin
	glGetIntegerv (GL_VIEWPORT, viewport);
	glGetDoublev (GL_MODELVIEW_MATRIX, mvmatrix);
	glGetDoublev (GL_PROJECTION_MATRIX, projmatrix);
	gluProject( X , Y , Z , Mvmatrix, projmatrix, viewport , @WinX, @WinY, @WinZ );

	if ( WinX >= 1 ) and ( WinX <= ScreenWidth ) and ( WinY >= 17 ) and ( WinY <= ScreenHeight ) then begin
		MyDest.X := WinX;
		MyDest.Y := WinY - 16;
		QuickTextC( GearName( M ) , MyDest , StdWhite , game_font );
	end;
end;

Procedure RenderMap( GB: GameBoardPtr );
	{ Render the location stored in G_Map, along with all items and characters on it. }
	{ Also save the position of the mouse pointer, in world coordinates. }
var
	X,Y,Z: Integer;
	BZ: GLFloat;
	SX,SY,SZ,W,H: GLDouble;
	Frame: Integer;
	Viewport: TViewPortArray;
	mvmatrix,projmatrix: T16DArray;
	M: GearPtr;
begin
	glDisable( GL_BLEND );

	glClear( GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );
	if Current_Backdrop <> 0 then begin
		DrawSkybox( Current_Backdrop );
	end;

	glMatrixMode( GL_PROJECTION );
	glLoadIdentity;

	if Use_Isometric_Mode then begin
		{ Isometric display. }
		glOrtho( -( origin_zoom * 0.7 ) , ( origin_zoom * 0.7 ) , -( origin_zoom / 2 ) , ( origin_zoom / 2 ) , -100 , 100 );
		gluLookAt( origin_x + 0.5 + FineDir[origin_d,1] , 1.0 , origin_y + 0.5 + FineDir[origin_d,2] , origin_x + 0.5 , 0.5 , origin_y + 0.5 , 0 , 1 , 0 );
	end else begin
		{ Perspective display with linear crane. }
		gluPerspective( 25.0, screenwidth/screenheight , 2, 256.0 );
		gluLookAt( origin_x + 0.5 + FineDir[origin_d,1]*origin_zoom*2 , Camera_Crane_Height[ origin_zoom ] , origin_y + 0.5 + FineDir[origin_d,2]* origin_zoom*2 , origin_x + 0.5 , 0.5 , origin_y + 0.5 , 0 , 1 , 0 );
	end;

	glMatrixMode( GL_MODELVIEW );
	glLoadIdentity();

	glEnable( GL_Depth_Test );

	glEnable( GL_ALPHA_TEST );
	glAlphaFunc( GL_Equal , 1.0 );

	SetLighting;

	{ Draw all the tiles in memory order. }
	for X := 1 to GB^.Map_Width do begin
		for Y := 1 to GB^.Map_Height do begin
			glMatrixMode( GL_MODELVIEW );
			glLoadIdentity();
			glTranslated( X - 1 , 0 , Y - 1 );

			if TileVisible( GB , X , Y ) then begin
				DrawTerrain( GB , TileTerrain( GB , X , Y ) , X , Y );
			end else begin
				DrawFloor( BitzTex[ 9 ] , -0.1 );
			end;

			{ While we're here, to save time, clear the model map. }
			for z := LoAlt to ( HiAlt + 1 ) do model_map[ X , Y , z ] := Nil;
		end;
	end;

	glDisable( GL_Lighting );
	glDisable( GL_Light1 );

	{ Draw the contents of the map. }
	M := GB^.Meks;
	while M <> Nil do begin
		if OnTheMap( GB , M ) and MekVisible( GB , M ) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			Z := MekAltitude( GB , M );
			glMatrixMode( GL_MODELVIEW );
			glLoadIdentity();
			glTranslated( X - 1 , 0 , Y - 1 );

			if ( M^.G = GG_Prop ) and ( M^.Stat[ STAT_PropMesh ] <> 0 ) then begin
				DrawPropMesh( M );
			end else if Destroyed( M ) then begin
				W := ( M^.Scale + 1 ) / ( GB^.Scale + 1 );
				H := Z / 2;
				if H < 0 then H := H * 0.75;
				if M^.G = GG_Character then Frame := Default_Dead_Thing
				else Frame := Default_Wreckage;

				DrawModel( SensibleTexID( Items_Sprite_Name , '' , Frame ) ,
						W,	{ width }
						0 ,	{ offset }
						H ,	{ foot }
						0 );	{ fade }

			end else if IsMasterGear( M ) then begin
				W := ( M^.Scale + 1 ) / ( GB^.Scale + 1 );
				H := Z / 2;
				if H < 0 then H := H * 0.75;

				DrawModel( SensibleTexID( SpriteName( M ) , SpriteColor( GB , M ) , ( NAttValue( M^.NA , NAG_Location , NAS_D ) - DirOffset[ origin_d ] + 10 ) mod 8 ) ,
						W,	{ width }
						-0.2 ,	{ offset }
						H ,	{ foot }
						0 );	{ fade }
				if OnTheMap( GB , X , Y ) and ( Z >= LoAlt ) and ( Z <= HiAlt ) then begin
					model_map[ X , Y , Z ] := M;
					if M^.Scale >= GB^.Scale then model_map[ X , Y , Z + 1 ] := M;
				end;

{				if Names_Above_Heads then DisplayName( M , X , Y , Z + 1.0 );
}
			end else if M^.G = GG_MetaTerrain then begin
				{ In GH1, metaterrain was drawn like any other sprite. }
				{ In GH2, different types of metaterrain get their own }
				{ rendering routines. }
				case M^.S of
				GS_MetaDoor:		if M^.Stat[ STAT_Pass ] = -100 then SmartWall( TT_Door , DoorBlue );
				GS_MetaStairsUp:	DrawStairs;
				GS_MetaStairsDown:	DrawFloor( TerrTex[ TT_StairsDown ] , 0.055 );
				GS_MetaTrapdoor:	DrawFloor( TerrTex[ TT_TrapDoor ] , 0.055 );
				GS_MetaElevator:	SmartWall( TT_Elevator , DoorBlue );
				GS_MetaBuilding:	begin
							{ Buildings require lighting. Reactivate it. }
							glEnable( GL_Lighting );
							glEnable( GL_Light1 );
							DrawBuilding( NAttValue( M^.NA , NAG_MTAppearance , NAS_BuildingMesh ) , M^.Stat[ STAT_Altitude ] );
							glDisable( GL_Lighting );
							glDisable( GL_Light1 );
							end;
				GS_MetaEncounter:	DrawEncounter( M );
				GS_MetaCloud,GS_MetaFire:		{ Do Nothing };
				else DrawModel( SensibleTexID( SpriteName( M ) , '' , NAttValue( M^.NA , NAG_Display , NAS_PrimaryFrame ) ) ,
						1.0,	{ width }
						-0.1 ,	{ offset }
						0 ,	{ foot }
						0 );	{ fade }
				end;
				if OnTheMap( GB , X , Y ) then begin
					for Z := LoAlt to HiAlt do begin
						if ( Z <= M^.Stat[ STAT_Altitude ] ) and ( model_map[ X , Y , Z ] = Nil ) then model_map[ X , Y , Z ] := M;
					end;
				end;

			end else begin
				DrawModel( SensibleTexID( SpriteName( M ) , '' , NAttValue( M^.NA , NAG_Display , NAS_PrimaryFrame ) ) ,
					0.75,	{ width }
					0.0 ,	{ offset }
					Z / 2 ,	{ foot }
					0 );	{ fade }
				if ( Z >= LoAlt ) and ( Z <= HiAlt ) and ( model_map[ X , Y , Z ] = Nil ) then model_map[ X , Y , Z ] := M;
			end;
		end;
		M := M^.Next;
	end;

	glDisable( GL_Texture_2D );
	glDisable( GL_ALPHA_TEST );


	{ Record the coordinates of the mouse, in map terms. }
	glMatrixMode( GL_MODELVIEW );
	glLoadIdentity();

	glGetIntegerv (GL_VIEWPORT, viewport);
	glGetDoublev (GL_MODELVIEW_MATRIX, mvmatrix);
	glGetDoublev (GL_PROJECTION_MATRIX, projmatrix);

	glReadPixels( mouse_x, screenheight - mouse_y, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, @BZ);

	gluUnProject( Mouse_X , screenheight - Mouse_Y , BZ , mvmatrix , projmatrix , viewPort , @SX , @SY , @SZ );
	tile_X := Floor( SX ) + 1;
	tile_Y := Floor( SZ ) + 1;
	if SY < 0 then SY := SY * 1.33;
	tile_Z := Floor( SY * 2 );


	{ Draw the water and the overlays. }
	{ We do this after rrecording the mouse pos, so it won't interfere. }
	for X := 1 to GB^.Map_Width do begin
		for Y := 1 to GB^.Map_Height do begin
			glMatrixMode( GL_MODELVIEW );
			glLoadIdentity();
			glTranslated( X - 1 , 0 , Y - 1 );

			glEnable( GL_ALPHA_TEST );
			for Z := LoAlt to -1 do begin
				if Underlays[ X , Y , Z ] > 0 then begin
					DrawFloor( BitzTex[ Underlays[ X , Y , Z ] ] , 0.01 );
				end;
				if Overlays[ X , Y , Z ] > 0 then begin
					glDisable( GL_Lighting );
					DrawModel( Overlays[ X , Y , Z ] ,
						1.0,	{ width }
						-0.3 ,	{ offset }
						Z / 2 ,	{ foot }
						0 );	{ fade }
					glEnable( GL_Lighting );
				end;
			end;
			glDisable( GL_ALPHA_TEST );

			if TileVisible( GB , X , Y ) then begin
				{ Depending on the terrain, draw it. }
				Case TileTerrain( GB , X , Y ) of
				4,17,18:	DrawWave( TT_Water , ( X + Y ) mod 2 + 1 );
				end;
			end;

			glEnable( GL_ALPHA_TEST );
			for Z := 0 to HiAlt do begin
				if Underlays[ X , Y , Z ] > 0 then begin
					DrawFloor( BitzTex[ Underlays[ X , Y , Z ] ] , 0.01 );
				end;
				if Overlays[ X , Y , Z ] > 0 then begin
					DrawModel( Overlays[ X , Y , Z ] ,
						1.0,	{ width }
						-0.3 ,	{ offset }
						Z / 2 ,	{ foot }
						0 );	{ fade }
				end;
			end;
			glDisable( GL_ALPHA_TEST );

		end;
	end;

	{ Draw the clouds and fire. }
	M := GB^.Meks;
	while M <> Nil do begin
		if ( M^.G = GG_MetaTerrain ) and ( ( M^.S = GS_MetaCloud ) or ( M^.S = GS_MetaFire ) ) and OnTheMap( GB , M ) and MekVisible( GB , M ) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			glMatrixMode( GL_MODELVIEW );
			glLoadIdentity();
			glTranslated( X - 1 , 0 , Y - 1 );

			if M^.S = GS_MetaCloud then begin
				{ The color used for the cloud is going to depend }
				{ on whether it has some effect or not. }
				if SAttValue( M^.SA , 'EFFECT' ) = '' then begin
					DrawTransBox( BitzTex[ 3 + (( Animation_Phase + X * 17 + Y * 23 ) div 10 ) mod 3 ] , 0.25 , M^.Stat[ STAT_Altitude ] / 2 , SmokeGray );
				end else begin
					DrawTransBox( BitzTex[ 3 + (( Animation_Phase + X * 17 + Y * 23 ) div 10 ) mod 3 ] , 0.25 , M^.Stat[ STAT_Altitude ] / 2 , ToxicGreen );
				end;
			end else begin
				DrawTransBox( BitzTex[ 6 + ( Animation_Phase div 2 + X * 29 + Y * 31 ) mod 3 ] , 0 , M^.Stat[ STAT_Altitude ] / 2 , StdWhite );
			end;
		end;
		M := M^.Next;
	end;

	glDisable( GL_Depth_Test );

	{ Do the tactics cursor. }
	if Tactics_Turn_In_Progess and ( Focused_On_Mek <> Nil ) then begin
		X := NAttValue( Focused_On_Mek^.NA , NAG_Location , NAS_X );
		Y := NAttValue( Focused_On_Mek^.NA , NAG_Location , NAS_Y );
		glMatrixMode( GL_MODELVIEW );
		glLoadIdentity();
		glTranslated( X - 1 , 0 , Y - 1 );
		DrawTacticsCursor;
	end;

end;


Procedure FillFineDir;
	{ Fill the "Fine Dir" array with data. }
var
	T: Integer;
begin
	for t := 0 to ( Num_Rotation_Angles - 1 ) do begin
		FineDir[ T , 1 ] := Cos( -Pi * 2 * t / Num_Rotation_Angles );
		FineDir[ T , 2 ] := -Sin( -Pi * 2 * t / Num_Rotation_Angles );
		DirOffset[ T ] := ( ( ( t + Num_Rotation_Angles div 16 ) * 8 ) div Num_Rotation_Angles ) mod 8;
	end;

	for t := LowZoom to HiZoom do begin
		Camera_Crane_Height[t] := T * 0.866;
	end;
end;

Procedure LoadTerrTex( TileSet: Integer );
	{ Load a tileset from disk. }
const
	Tile_Filenames: Array [0..NumTileSet] of String = (
		'terr_default.png', 'terr_rocky.png', 'terr_palacepark.png',
		'terr_industrial.png'
	);
var
	tmp: PSDL_Surface;
	T2: SensibleSpritePtr;
	MySource: TSDL_Rect;
	T: Integer;
begin
	{ Get rid of current tiles, if appropriate. }
	glDeleteTextures( Num_Terrain_Textures, @TerrTex );

	{ Create a temporary image for the transfer. }
	tmp := SDL_CreateRGBSurface( SDL_SWSURFACE , 32 , 32 , 32 , $000000ff , $0000ff00 , $00ff0000 , $ff000000 );
	MySource.X := 0;
	MySource.Y := 0;

	T2 := LocateSprite( Tile_Filenames[ TileSet ] , 32 , 32 );

	{ Transfer the images one by one to gl textures. }
	for t := 1 to Num_Terrain_Textures do begin
		SDL_FillRect( tmp , Nil , SDL_MapRGBA( tmp^.Format , 0 , 0 , 255 , 0 ) );
		DrawSprite( t2 , tmp , MySource , T-1 );
		glBindTexture( GL_TEXTURE_2D, TerrTex[T] );
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
		glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
		glTexImage2D(GL_TEXTURE_2D,0,4,tmp^.w,tmp^.h,0,GL_RGBA,GL_UNSIGNED_BYTE,tmp^.pixels);
	end;
	glFinish;

	{ Get rid of dynamic resources. }
	RemoveSprite( t2 );
	SDL_FreeSurface(tmp);

	{ Record the tileset number. }
	Current_Tileset := TileSet;
end;

Procedure LoadTextures;
	{ Load the textures for the walls, and format them for OpenGL. }
var
	tmp: PSDL_Surface;
	T2: SensibleSpritePtr;
	MySource: TSDL_Rect;
	T: Integer;
begin
	{ Create a temporary image for the transfer. }
	tmp := SDL_CreateRGBSurface( SDL_SWSURFACE , 32 , 32 , 32 , $000000ff , $0000ff00 , $00ff0000 , $ff000000 );

	MySource.X := 0;
	MySource.Y := 0;

	{ First, generate names for the textures, and load the terrain image sprite. }
	glGenTextures( Num_Terrain_Textures, @TerrTex );
	LoadTerrTex( NAV_DefaultTiles );

	{ Next do the exact same thing for the bitz textures. }
	glGenTextures( Num_Bitz_Textures, @BitzTex );
	T2 := LocateSprite( 'bitz.png' , 32 , 32 );

	{ Transfer the images one by one to gl textures. }
	for t := 1 to Num_Bitz_Textures do begin
		SDL_FillRect( tmp , Nil , SDL_MapRGBA( tmp^.Format , 0 , 0 , 255 , 0 ) );
		DrawSprite( t2 , tmp , MySource , T-1 );
		glBindTexture( GL_TEXTURE_2D, BitzTex[T] );
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
		glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
		glTexImage2D(GL_TEXTURE_2D,0,4,tmp^.w,tmp^.h,0,GL_RGBA,GL_UNSIGNED_BYTE,tmp^.pixels);
	end;
	glFinish;
	RemoveSprite( t2 );

	{ Also the building textures. }
	glGenTextures( Num_Building_Textures, @BuildingTex );
	T2 := LocateSprite( 'buildings_default.png' , 32 , 32 );

	{ Transfer the images one by one to gl textures. }
	for t := 1 to Num_Building_Textures do begin
		SDL_FillRect( tmp , Nil , SDL_MapRGBA( tmp^.Format , 0 , 0 , 255 , 0 ) );
		DrawSprite( t2 , tmp , MySource , T-1 );
		glBindTexture( GL_TEXTURE_2D, BuildingTex[T] );
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
		glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
		glTexImage2D(GL_TEXTURE_2D,0,4,tmp^.w,tmp^.h,0,GL_RGBA,GL_UNSIGNED_BYTE,tmp^.pixels);
	end;
	glFinish;
	RemoveSprite( t2 );
	SDL_FreeSurface(tmp);

	glGenTextures( 1, @SpaceTex );
	tmp := SDL_CreateRGBSurface( SDL_SWSURFACE , 512 , 512 , 32 , $000000ff , $0000ff00 , $00ff0000 , $ff000000 );
	T2 := LocateSprite( 'bg_space.png' , 512 , 512 );
	SDL_FillRect( tmp , Nil , SDL_MapRGBA( tmp^.Format , 0 , 0 , 255 , 0 ) );
	DrawSprite( t2 , tmp , MySource , 0 );
	glBindTexture( GL_TEXTURE_2D, SpaceTex );
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
	glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
	glTexImage2D(GL_TEXTURE_2D,0,4,tmp^.w,tmp^.h,0,GL_RGBA,GL_UNSIGNED_BYTE,tmp^.pixels);
	RemoveSprite( t2 );
	SDL_FreeSurface(tmp);
end;

Procedure GeneratePropMeshes;
	{ Generate some meshes to be used with the new "Action Props". }
var
	T: Integer;
begin
	for t := 1 to Num_Prop_Meshes do begin
		Load_Obj_Mesh( data_directory + 'mesh' + BStr( T ) + '.obj' , T );
	end;
end;

Procedure FocusOn( Mek: GearPtr );
	{ Focus on the provided mecha. }
begin
	if Mek <> Nil then begin
		origin_x := NAttValue( Mek^.NA , NAG_Location , NAS_X ) - 1;
		origin_y := NAttValue( Mek^.NA , NAG_Location , NAS_Y ) - 1;
		if not Use_Isometric_Mode then begin
			origin_d_target := ( ( ( NAttValue( Mek^.NA , NAG_Location , NAS_D ) + 4 ) * Num_Rotation_Angles ) div 8 ) mod Num_Rotation_Angles;
			if Focused_On_Mek = Nil then origin_d := origin_d_target;
		end;
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
const
	Half_Rot_Angle = Num_Rotation_Angles div 2;
var
	L: Integer;
begin
	if Mouse_X < 20 then begin
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
		AddOverlay( GB , P.X , P.Y , P.Z , Strong_Hit_Sprite^.Img[0] );
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
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , Strong_Hit_Sprite^.Img[ AnimOb^.V ] );

				end;
		GS_ArmorDefHit: begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] ,  Weak_Hit_Sprite^.Img[ AnimOb^.V ] );

				end;

		GS_Parry,GS_Block,GS_Intercept,GS_Resist:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] ,  Parry_Sprite^.Img[ ( AnimOb^.V + 1 ) div 2 ] );
				Inc( AnimOb^.V );
				end;

		GS_Dodge,GS_ECMDef:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , Miss_Sprite^.Img[ ( AnimOb^.V + 1 ) div 2 ] );
				Inc( AnimOb^.V );
				end;

		GS_Backlash:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , Strong_Hit_Sprite^.Img[ AnimOb^.V ] );

				end;
		GS_AreaAttack:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , Strong_Hit_Sprite^.Img[ AnimOb^.V ] );

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
	{ If we're using isometric mode, set the camera to the default angle. }
	if Use_Isometric_Mode then begin
		origin_d := ( ( 9 * Num_Rotation_Angles ) div 8 ) mod Num_Rotation_Angles;
		origin_d_target := origin_d;
	end;

	{ See if we need to load a new tile set. }
	if ( GB^.Scene <> Nil ) then TileSet := NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_TileSet )
	else TileSet := NAV_DefaultTiles;
	if TileSet <> Current_TileSet then LoadTerrTex( TileSet );

	{ Also set the backdrop. }
	if GB^.Scene <> Nil then begin
		BDNum := NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_Backdrop );
		if BDNum > 0 then begin
			Current_Backdrop := SpaceTex;
		end else Current_Backdrop := 0;
	end else begin
		Current_Backdrop := 0;
	end;
end;

initialization
	RPGKey;

	SDL_PumpEvents;
	SDL_GetMouseState( Mouse_X , Mouse_Y );


	LoadTextures;
	GeneratePropMeshes;
	tile_x := 1;
	tile_y := 1;

	origin_zoom := 10;
	origin_d := 1;
	origin_d_target := 1;
	FillFineDir;

	Mini_Map_Sprite := LocateSprite( 'minimap.png' , 3 , 3 );
	World_Terrain := LocateSprite( 'world_terrain.png' , 64 , 64 );

	Strong_Hit_Sprite := LocateTexture( Strong_Hit_Sprite_Name , '' );
	Weak_Hit_Sprite := LocateTexture( Weak_Hit_Sprite_Name , '' );
	Parry_Sprite := LocateTexture( Parry_Sprite_Name , '' );
	Miss_Sprite := LocateTexture( Miss_Sprite_Name , '' );

	Current_Backdrop := 0;

	ClearOverlays;
	Focused_On_Mek := Nil;

finalization
	glDeleteTextures( Num_Terrain_Textures, @TerrTex );

end.
