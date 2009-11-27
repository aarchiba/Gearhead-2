unit gl_objreader;
	{ This unit contains one function: a Wavefront .obj file reader. }
	{ The mesh is loaded from disk and stored as an opengl display list. }

	{ OpenGL should be initialized before this unit is called! Very important, that... }
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

uses texutil,gl;

const
	Mesh_Dirname = 'mesh';
	Mesh_Directory = Mesh_Dirname + DirectorySeparator;

type
	SensibleMeshPtr = ^SensibleMesh;
	SensibleMesh = Record
		Name: String;
		DLID: Integer;
		Next: SensibleMeshPtr;
	end;

var
	Game_Meshes: SensibleMeshPtr;


Procedure Load_Obj_Mesh( const fname: String; DLID: Integer );

Function LocateMesh( Name: String ): SensibleMeshPtr;
Function SensibleMeshID( const Name: String ): GLUInt;
Procedure RemoveMesh( var LMember: SensibleMeshPtr );


implementation

type
	gl_point = Record
		X,Y,Z: GLFLoat;
	end;
	glpointarray = Array of gl_point;


Procedure Load_Obj_Mesh( const fname: String; DLID: Integer );
	{ Load this object from disk. Store it as a display list with the provided }
	{ display list ID. }
var
	F: Text;
	TheLine, cmd: String;
	v_list,vt_list,vn_list: glpointarray;
	v_n,v_length,vt_n,vt_length,vn_n,vn_length: Integer;

	Procedure ReadVertex( var Ver_List: glpointarray; var Ver_N, Ver_Length: INteger );
		{ Read a vertex from TheLine. This procedure works for normal }
		{ verticies, normals, and texture coordinates... I realize texture coords }
		{ only have two coordinates instead of three, but the third one will be }
		{ zero and no-one cares. }
	begin
		if ver_n >= ver_length then begin
			ver_length := ver_length * 2;
			SetLength( ver_list , ver_length );
		end;

		ver_list[ver_n].X := ExtractReal( TheLine );
		ver_list[ver_n].Y := ExtractReal( TheLine );
		ver_list[ver_n].Z := ExtractReal( TheLine );
		Inc( ver_n );
	end;

	Function ExtractSlashValue( var S: String ): Integer;
		{ Extract a string beginning at the first character and continuing }
		{ until either the end of the string or until a slash is detected. }
	var
		A2: Integer;
		S2: String;
	begin
		A2 := Pos('/',S);
		if A2 = 0 then A2 := Length( S ) + 1;
		S2 := Copy( S , 1 , A2 - 1 );
		S := Copy( S , A2 + 1 , Length( S ) );
		ExtractSlashValue := ExtractValue( S2 );
	end;

	Procedure AddFace;
		{ We've just encountered a "F". Go through those silly three-pronged }
		{ number-lumps and draw everything as intended. }
	var
		TPNLump: String;	{ What? What was I supposed to call it? }
		V,VN,VT: Integer;
	begin
		{ To start with, begin a polygon. }
		glBegin( GL_POLYGON );

		{ Keep going until we run out of points to process. }
		while TheLine <> '' do begin
			{ Extract the next triple-pronged number lump. }
			TPNLump := ExtractWord( TheLine );

			{ Extract the three coords needed from it. }
			V := ExtractSlashValue( TPNLump ) - 1;
			VT := ExtractSlashValue( TPNLump ) - 1;
			VN := ExtractSlashValue( TPNLump ) - 1;

			{ Do the drawing. }
			glTexCoord2f( 1 - vt_list[ vt ].X , 1 - vt_list[ vt ].Y );
			glNormal3f( vn_list[ vn ].X , vn_list[ vn ].Y , vn_list[ vn ].Z );
			glVertex3f( v_list[ v ].X , v_list[ v ].Y , v_list[ v ].Z );
		end;

		{ End the shape. }
		glEnd;
	end;
begin
	{ Initialize the point arrays. }
	SetLength( v_list , 100 );
	SetLength( vt_list , 100 );
	SetLength( vn_list , 100 );
	v_n := 0;
	vt_n := 0;
	vn_n := 0;
	v_length := 100;
	vt_length := 100;
	vn_length := 100;

	Assign( F , fname );
	Reset( F );
	glNewList( DLID , GL_COMPILE );

	while not Eof( F ) do begin
		readln(F,TheLine);
		DeleteWhiteSpace(TheLine);

		{ If this isn't a comment or an empty line, process the commands. }
		if ( TheLine <> '' ) and ( TheLine[1] <> '#' ) then begin
			while TheLine <> '' do begin
				cmd := UpCase( ExtractWord( TheLine ) );

				if cmd = 'V' then begin
					ReadVertex( v_list , v_n , v_length );

				end else if cmd = 'VN' then begin
					ReadVertex( vn_list , vn_n , vn_length );

				end else if cmd = 'VT' then begin
					ReadVertex( vt_list , vt_n , vt_length );

				end else if cmd = 'F' then begin
					{ FACE- the BIG one!!! }
					AddFace;

				end;
			end;
		end;
	end;

	glEndList();
	Close( F );
end;

Function NewMesh: SensibleMeshPtr;
	{ Add an empty mesh description to the list. }
	{ Give it a mesh name. }
var
	it: SensibleMeshPtr;
begin
	{ Allocate a SensibleMesh and initialize it. }
	New(it);
	if it = Nil then exit( Nil );
	{Initialize values.}
	it^.DLID := glGenLists( 1 );
	if it^.DLID = 0 then begin
		Dispose( it );
		Exit( Nil );
	end else begin
		it^.Next := Game_Meshes;
		Game_Meshes := it;
		NewMesh := it;
	end;
end;
Function AddSensibleMesh( Name: String ): SensibleMeshPtr;
	{ Add a mesh to the list. }
var
	MyMesh: SensibleMeshPtr;
	T: Integer;
begin
	{ Allocate a new mesh. }
	MyMesh := NewMesh;
	MyMesh^.Name := UpCase( Name );

	{ Load the object referenced by the name. }
	Load_Obj_Mesh( Mesh_Directory + Name , MyMesh^.DLID );

	AddSensibleMesh := MyMesh;
end;


Function LocateMesh( Name: String ): SensibleMeshPtr;
	{ Get the number of the texture identified by the provided ID number. }
var
	T,it: SensibleMeshPtr;
begin
	T := Game_Meshes;
	it := Nil;
	name := Upcase( Name );
	while T <> Nil do begin
		if ( T^.name = name ) then it := T;
		T := T^.Next;
	end;
	if it = Nil then it := AddSensibleMesh( name );
	LocateMesh := it;
end;

Function SensibleMeshID( const Name: String ): GLUInt;
	{ Return the ID for the requested mesh. }
var
	SM: SensibleMeshPtr;
begin
	SM := LocateMesh( name );
	SensibleMeshID := SM^.DLID;
end;

Procedure RemoveMesh( var LMember: SensibleMeshPtr );
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: SensibleMeshPtr;
begin
	{Initialize A and B}
	B := Game_Meshes;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		writeln('ERROR- RemoveMesh asked to remove a mesh that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		Game_Meshes := B^.Next;
		B^.Next := Nil;

		glDeleteLists( B^.DLID , 1 );
		Dispose( B );

		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		B^.Next := Nil;

		glDeleteLists( B^.DLID , 1 );
		Dispose( B );
	end;
end;


end.
