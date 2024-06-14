# HalfedgeMesh.m

<img width="445" alt="test" src="https://github.com/GeometryCollective/MathematicaHalfedge/assets/3604525/40198f0c-571a-4aaa-b1be-2daa17b30644">

This _Mathematica_ package provides an implementation of the halfedge mesh data structure aimed at quick prototyping and concise, legible mesh navigation code.  It is not intended for large-scale/high-performance mesh processing, nor is it well-packaged/encapsulated, since it assumes a single mesh (and defines functions that pollute the global namespace).

Its basic function is to convert standard vertex-face connectivity to halfedge connectivity.  It also provides helper functions that make it easy to access mesh elements, using syntax like

```Mathematica
oppositeEdge = v//he//next//edge
```

## Usage

### Loading

The package can be loaded via

```Mathematica
Import["HalfedgeMesh.m"];
```

(Note that the path must be set so that the package is accessible.  To load it from the local directory of the notebook, you can first write `SetDirectory[NotebookDirectory[]];`.)

### Converting to halfedge

The main method in the package is `BuildHalfedge[polygons]`, which builds halfedge connectivity information and associated helper functions.  For instance, suppose we define a small mesh of two triangles inline as

```Mathematica
vertexCoordinates = {{1, 1, 0}, {0, 1, 0}, {0, 0, 0}, {-1, 0, 0}};
polygons = {{1, 2, 3}, {3, 2, 4}};
```

We can then convert to halfedge connectivity via

```Mathematica
{mesh, twin, next, vertex, edge, face, he} = BuildHalfedge[polygons];
```

From here, usage looks much like any other halfedge mesh data structure.  For instance, to compute the surface area we could write

```Mathematica
(* Compute the mean edge length by accumulating the total *)
(* edge length, then dividing by the number of edges. *)

totalLength = 0;

Do[ (* iterate over edges e *)
  h = e // he; (*
  get one of the halfedges h of e *)

  (* get the two vertices v1,v2 of e *)
  v1 = h // vertex;
  v2 = h // twin // vertex;

  (* get the locations of the two endpoints *)

  p1 = vertexCoordinates[[v1]];
  p2 = vertexCoordinates[[v2]];

  (* add the length to our total *)
  totalLength += Norm[p1 - p2];
  ,
  {e, mesh["edges"]}
];

meanEdgeLength = totalLength/Length[mesh["edges"]]
```

### Utility functions

Since Mathematica's built-in mesh loaders either (i) triangulate all polygons (e.g., `Import["mesh.obj"]`) or (ii) provide only a polygon soup (e.g., `Import["mesh.obj",PolygonData]`), the notebook also provides a method `LoadPolygonalOBJ[filename]` that loads a general polygon mesh with proper connectivity.

### (Optional Reading) Internal representation

The package can largely be used without needing to know about the internal representation of data.  However, this encoding can be useful for, e.g., writing custom helper functions.

The basic idea of the encoding is that:

- Each halfedge is represented by just an ordinary integer index `i`.
- Each vertex/edge/face is represented by a pair `(d,i)` where `d` is the dimension of the element (1/2/3) and `i` is its index.

The `mesh` itself is then just a collection of element lists; the methods `twin`, `next`, etc., operate on these elements to access adjacent elements.  More specifically, the method `BuildHalfedge` hence builds the following data:

- The association `mesh` contains lists of all mesh elements.  Each halfedge is just a raw index; each vertex/edge/face is a pair, where the first element gives the dimension of the element:
   - `mesh["halfedges"]` — halfedges as raw indices 1, …, |H|
   - `mesh["vertices"]` — vertices as pairs {1,1}, {1,2}, …, {1,|V|}
   - `mesh["edges"]` — edges as pairs {2,1}, {2,2}, …, {1,|V|}
   - `mesh["faces"]` — faces as pairs {3,1}, {3,2}, …, {1,|V|}
- The function `twin[h]` gives the twin of `h`.
- The function `next[h]` gives the next halfedge following `h` within its polygon, as an index.
- The function `vertex[h]` gives the vertex at the tail of `h`, as a pair `{1,v}`).
- The function `edge[h]` gives the edge containing `h`, as a pair `{2,e}`).
- The function `face[h]` gives the face containing `h`, as a pair `{3,f}`).

