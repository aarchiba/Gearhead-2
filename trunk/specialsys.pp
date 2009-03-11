unit specialsys;
	{ This unit handles special systems- GG_Usable gears. }
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

uses gears,locale;


Function CanDoTransformation( GB: GameBoardPtr; mek,part: GearPtr ): Boolean;
Procedure DoTransformation( GB: GameBoardPtr; mek,part: GearPtr );


implementation

uses movement,ghmodule;

Function CanDoTransformation( GB: GameBoardPtr; mek,part: GearPtr ): Boolean;
	{ Return TRUE if the provided mecha can transform to the requested form }
	{ given the terrain conditions, or FALSE otherwise. }
var
	P: Point;
	MMFound: Boolean;
	T,Terrain,OMM: Integer;
begin
	{ Do the transformation first. }
	OMM := NAttValue( mek^.NA , NAG_Action , NAS_Movemode );
	DoTransformation( GB , mek , part );

	{ Assume FALSE unless shown to be true. }
	MMFound := False;

	{ Determine the position of this mecha. }
	P := GearCurrentLocation( Mek );
	if OnTheMap( GB , P.X , P.Y ) then begin
		{ Check to make sure there's at least one movemode usable in the new form }
		{ which is not blocked in this tile. }
		Terrain := TileTerrain( GB , P.X , P.Y );

		for T := 1 to NumMoveMode do begin
			if BaseMoveRate( GB^.Scene , Mek , T ) > 0 then begin
				if not IsBlockingTerrainForMM( GB, Mek, Terrain, T ) then begin
					MMFound := True;
					Break;
				end;
			end;
		end;
	end;

	DoTransformation( GB , mek , part );
	SetNAtt( mek^.NA , NAG_Action , NAS_Movemode , OMM );
	CanDoTransformation := MMFound;
end;

Procedure DoTransformation( GB: GameBoardPtr; mek,part: GearPtr );
	{ This mecha is about to do a transformation. }
	{ The steps involved are: }
	{ - Swap the mecha form. }
	{ - Swap the mecha's visual representation. }
	{ - Transform limbs as needed. }
	{ - Set a new movement mode. }
	{ If this function is called, assume that the transformation is legal. }
var
	SpriteName: String;
	Form: Integer;
	TMod: GearPtr;
begin
	{ Swap the form. }
	Form := mek^.s;
	mek^.S := Part^.V;
	Part^.V := Form;

	{ Swap the sprites. }
	SpriteName := SAttValue( mek^.SA , 'SDL_SPRITE' );
	SetSAtt( mek^.SA , 'SDL_SPRITE <' + SAttValue( part^.SA , 'SDL_SPRITE2' ) + '>' );
	SetSAtt( part^.SA , 'SDL_SPRITE2 <' + SpriteName + '>' );
	SpriteName := SAttValue( mek^.SA , 'CUTE_SPRITE' );
	SetSAtt( mek^.SA , 'CUTE_SPRITE <' + SAttValue( part^.SA , 'CUTE_SPRITE2' ) + '>' );
	SetSAtt( part^.SA , 'CUTE_SPRITE2 <' + SpriteName + '>' );

	{ Transform the limbs as needed. }
	TMod := Mek^.SubCom;
	while TMod <> Nil do begin
		if ( TMod^.G = GG_Module ) and ( TMod^.Stat[ STAT_VariableModuleForm ] <> 0 ) then begin
			if FORMxMODULE[ Mek^.S , TMod^.Stat[ STAT_PrimaryModuleForm ] ] then begin
				TMod^.S := TMod^.Stat[ STAT_PrimaryModuleForm ];
			end else if FORMxMODULE[ Mek^.S , TMod^.Stat[ STAT_VariableModuleForm ] ] then begin
				TMod^.S := TMod^.Stat[ STAT_VariableModuleForm ];
			end else begin
				TMod^.S := TMod^.Stat[ STAT_PrimaryModuleForm ];
			end;
		end;

		TMod := TMod^.Next;
	end;

	{ Set a new movement mode. }
	GearDownToLowestMM( Mek , GB , NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) );
end;

end.
