(* ::Package:: *)

(* ::Input::Initialization:: *)
(* Convert a string s encoding a floating point number in scientific notation to a real number. *)
ToReal[s_]:=If[$VersionNumber<12.3,Internal`StringToDouble[s],Internal`StringToMReal[s]];

(* Load an OBJ file with polygonal faces into a list of vertex coordinates, and a list of polygons.  Note: we cannot use Mathematica's built in routines for import, which either triangulate polygons, or just provide polygon soup. *)
LoadPolygonalOBJ[filename_]:=Module[{lines,vertexList,faceList,tokens,vertex,face},
lines=ReadList[filename,String];
vertexList={};
faceList={};
Do[
If[StringTake[line,2]=="v ",
tokens=line//StringSplit;
vertex=ToReal/@Drop[tokens,1];
AppendTo[vertexList,vertex];
];
If[StringTake[line,2]=="f ",
tokens=line//StringSplit//StringSplit[#,"/"]&//ToExpression;
face=Drop[First/@tokens,1];
AppendTo[faceList,face];
],
{line,lines}
];
Return[{vertexList,faceList}];
];

(* Convert from polygon list to halfedge *)
BuildHalfedge[polygons_]:=Module[{nVertices,e,h,twinList,nextList,heVertex,heEdge,heFace,vertexHe,edgeHe,faceHe,heList,twin,next,vertex,edge,face,he,mesh},

(* get number of vertices by counting unique indices in polygon list *)
nVertices=polygons//Flatten//Union//Length;

(* list halfedges *)
h=ArrayFlatten[{#,RotateLeft[#]}\[Transpose]&/@polygons,1];

(* define canonical edges *)
e=Union[Sort/@h];

(* find twins, using -1 to indicate that a boundary halfedge has no twin *)
twinList=(Position[h,Reverse[#]]&/@h)/.{{}->-1}//Flatten;

(* list next halfedges *)
nextList=(RotateLeft[Table[k,{k,1,#}]]&/@(Length/@polygons))+Accumulate[Length/@Drop[Join[{0},polygons],-1]]//Flatten;

(* map from halfedges to incident vertex/edge/face *)
heVertex=First/@h;
heEdge=Position[e,Sort[#]]&/@h//Flatten;
heFace=Table[Array[k&,Length[polygons[[k]]]],{k,1,Length[polygons]}]//Flatten;

(* map from vertex/edge/face to a halfedge *)
vertexHe=Table[First[Position[heVertex,k]],{k,1,nVertices}]//Flatten;
edgeHe=Table[First[Position[Sort/@h,e[[k]]]],{k,1,Length[e]}]//Flatten;
faceHe=Table[First[Position[heFace,k]],{k,1,Length[polygons]}]//Flatten;

(* define functions for navigating the mesh *)
twin[he_]:=twinList[[he]];
next[he_]:=nextList[[he]];
vertex[v_]:={1,heVertex[[v]]};
edge[e_]:={2,heEdge[[e]]};
face[f_]:={3,heFace[[f]]};
heList={vertexHe,edgeHe,faceHe};
he[{degree_,element_}]:=heList[[degree,element]];

(* Generate mesh, which is just a collection of element lists *)
(* A halfedge is just a raw index i; a vertex/edge/face is a pair {d,i} where d is the element degree and i is the index. *)
mesh=Association[{
"halfedges"->Range[Length[twinList]], (* 1, \[Ellipsis], |H| *)
"vertices"->({1,#}&/@Range[Length[vertexHe]]), (* {1,1}, {1,2}, {1,3}, \[Ellipsis], |V| *)
"edges"->({2,#}&/@Range[Length[edgeHe]]), (* {2,1}, {2,2}, {2,3}, \[Ellipsis], |E| *)
"faces"->({3,#}&/@Range[Length[faceHe]]) (* {3,1}, {3,2}, {3,3}, \[Ellipsis], |F| *)
}];

Return[{mesh,twin,next,vertex,edge,face,he}]
];
