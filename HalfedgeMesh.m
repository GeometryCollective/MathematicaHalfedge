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

(* Returns true if and only if h is contained in the mesh boundary. *)
isBoundaryHalfedge[h_]:=(h//twin)==-1;

(* Returns true if and only if v is contained in the domain boundary *)
isBoundaryVertex[v_]:=Module[{h},
h=he[v];
While[True,
If[isBoundaryHalfedge[h],Return[True]];
h=h//twin//next;
If[h==he[v],Break[]];
];
Return[False];
];

(* Returns true if and only if e is contained in the domain boundary *)
isBoundaryEdge[e_]:=Module[{h},
h=e//he;
If[isBoundaryHalfedge[h],Return[True]];
h=h//twin;
If[isBoundaryHalfedge[h//twin],Return[True]];
Return[False];
];

(* Returns the index of a vertex, edge, or face. *)
index[{element_,i_}]:=i;

(* Returns the coordinates of vertex v *)
position[v_]:=vertexCoordinates[[v[[2]]]];

(* Returns the length of edge e *)
EdgeLength[e_]:=Module[{p1,p2},
p1=e//he//vertex//position;
p2=e//he//next//vertex//position;
Return[Norm[p2-p1]];
];

(* Returns the area of face f.  If f is a nonplanar polygon, returns the magnitude of the area vector (as computed by the shoelace formula.) *)
FaceArea[f_]:=Module[{pi,pj,h,A},
A=0;
h=f//he;
While[True,
pi=h//vertex//position;
pj=h//next//vertex//position;
A+=Cross[pi,pj]/2;
h=h//next;
If[h==(f//he),Break[]];
];
Return[Norm[A]];
];

(* Returns the interior angle at the head (not the tail) of halfedge h *)
CornerAngle[h_]:=Module[{p1,p2,p3,u,v},
p1=h//vertex//position;
p2=h//next//vertex//position;
p3=h//next//next//vertex//position;
u=p3-p2;
v=p1-p2;
Return[ArcTan[u . v,Norm[Cross[u,v]]]];
];

(* Computes the cotangent weight associated with halfedge h *)
HalfedgeCotan[h_]:=Module[{a,b,c,u,v},
a=h//next//next//vertex//position;
b=h//vertex//position;
c=h//next//vertex//position;
u=b-a;
v=c-a;
Return[u . v/Norm[Cross[u,v]]];
];

(* Computes the cotangent weight associated with edge e *)
EdgeCotan[e_]:=Module[{w,h},
w=0;
h=e//he;
w+=HalfedgeCotan[h];
If[!isBoundaryHalfedge[h//twin],
w+=HalfedgeCotan[h//twin];
];
Return[w];
];

(* Draw halfedge mesh *)
DrawHalfedgeMesh[]:=Module[{gVertices,gEdges,gBoundaryEdges,gFaces,gHalfedges,gBlue,v1,v2,h,gVerts,p1,p2,p3,t,n,m,l,u,q1,q2,gHalfedgeScale},
(* Vertices *)
gVertices=Sphere[#,.02]&/@vertexCoordinates;

(* Edges *)
gEdges={};
Do[
h=e//he;
If[!isBoundaryHalfedge[h],
v1=h//vertex;
v2=h//twin//vertex;
AppendTo[gEdges,Tube[{v1//position,v2//position}]]
],
{e,mesh["edges"]}
];

(* Boundary Edges *)
gBoundaryEdges={};
Do[
h=e//he;
If[isBoundaryHalfedge[h],
v1=h//vertex;
v2=h//next//vertex;
AppendTo[gBoundaryEdges,Tube[{v1//position,v2//position}]]
],
{e,mesh["edges"]}
];

(* Faces *)
gFaces={};
Do[
h=f//he;
gVerts={};
While[True,
AppendTo[gVerts,h//vertex//position];
h=h//next;
If[h==(f//he),Break[]];
];
AppendTo[gFaces,Polygon[gVerts]],
{f,mesh["faces"]}
];

(* Halfedges *)
gHalfedges={};
gHalfedgeScale=.7;
Do[
(* get three consecutive points from this face *)
p1=h//vertex//position;
p2=h//next//vertex//position;
p3=h//next//next//vertex//position;

(* compute normal and tangent *)
n=Cross[p3-p2,p1-p2]//Normalize;
t=Cross[n,p2-p1]//Normalize;

(* compute midpoint, length, and unit edge vector *)
m=(p1+p2)/2;
l=Norm[p2-p1];
u=Normalize[p2-p1];

(* endpoints of arrow *)
q1=m-gHalfedgeScale l u/2+.03t;
q2=m+gHalfedgeScale l u/2+.03t;
AppendTo[gHalfedges,Arrow[Tube[{q1,q2},.005]]],
{h,mesh["halfedges"]}
];

gBlue=RGBColor["#1b1f8a"];
Graphics3D[{
Darker[White,.7],gVertices,
Lighter[gBlue,.6],gEdges,
Darker[White,.7],gBoundaryEdges,
Lighter[gBlue,.8],EdgeForm[],gFaces,
White,Arrowheads[.02],gHalfedges
},Boxed->False,Lighting->"ThreePoint"]
];
