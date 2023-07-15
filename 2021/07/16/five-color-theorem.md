+++
title = "Five Color Theorem"
date = Date(2021, 7, 16)
hascode = true
rss = "The Five Color Theorem asserts that no planar graphs are 5-colorable."
tags = ["math"]
+++
# Theorem

For every [planar graph](planar_graph.md.html), there exists a coloring of its vertices using
at most 5 colors such that no two adjacent vertices have the same color.

## Lemma: degree 5 vertex

![](../images/five_color_theorem1.svg)

To show that every planar graph has at least 1 vertex of degree $\leq 5$, we assume [euler's formula](euler_formula.md.html), that given $F$ faces, $V$
vertices, and $E$ edges of a planar graph, that $$F + V = E + 2.$$

We assume for contradiction, there exists a planar graph $G = (F, V, E)$ with all vertices of
degree $\geq 6$. Then let us consider the size of this set:

$$VE = \{(v,e) : v \in V, e \in E, v \text{ is adjacent to } e\}$$

Every edge will be in there twice, so $$|VE| = 2|E|.$$ Also, we know that all
vertices have at least 6 edges, so $$|VE| \geq 6|V|.$$ Thus, $$2|E| \geq 6|V|
\implies \frac{1}{3}|E| \geq |V|.$$

Next, consider the set:

$$FE = \{(f,e) : e \in E, f \in F, f \text{ is adjacent to } e\}$$

Every edge can see 2 faces, so $$|FE| = 2|E|$$, and every face has at least 3
edges, so $$|FE| \geq 3|F|.$$ Putting this together, $$2|E| \geq 3|F| \implies
\frac{2}{3}|E| \geq |F|.$$

Now, we apply Euler's formula to get:

$$2 = F + V - E$$
$$\leq \frac{2}{3}|E| + \frac{1}{3}|E| - |E|$$
$$= 0$$

Thus, $2 \leq 0$, a contradiction.

$$\tag*{$\Box$}$$

## Proof

Now for the real proof. This proof is by induction on the number of vertices in
a planar graph:

Base case: $|V|=1$, it is clear that this is 5-colorable with just 1 color.

```dot
graph g {
layout = "neato"
node [
shape = "ellipse"
];
"w" [ label = "w" ];
"1" [ label = "1" ];
"2" [ label = "2" ];
"3" [ label = "3" ];
"4" [ label = "4" ];
"5" [ label = "5" ];
"6" [ label = "..." shape = "none" ];
"7" [ label = "..." shape = "none" ];
"8" [ label = "..." shape = "none" ];
"9" [ label = "..." shape = "none" ];
"10" [ label = "..." shape = "none" ];
"w" -- "1";
"w" -- "2";
"w" -- "3";
"w" -- "4";
"w" -- "5";
"1" -- "6";
"2" -- "7";
"3" -- "8";
"4" -- "9";
"5" -- "10";
}
```

Inductive step: We assume that all planar graphs with $|V|-1$ vertices are 5
colorable. We know from the lemma that there exists at least one vertex $w$ of
degree 5 or less. We know that if it has less degree less than 5 that we instantly win because if
we remove that vertex, it is 5 colorable (from our inductive hypothesis). And
because $w$ has degree less than 5 it can be colored by a color that isn't in
its neighbors. Thus, we can assume $w$ has 5 neighbors.

Now, becuase $w$ has 5 neighbors, if any two of them have the same color, then we
can color $w$ the color that is missing, so we can assume that $w$ has degree at
least 5.

To recap what we know so far: all planar graphs have at least one vertex with less than
degree 5. The worst case scenario for our proof is when it is exactly 5, and all
of the neighbors have different colors. All other cases we win.

Now, we label the neighbors $v_1$ through $v_5$ based on their colors. We look
at the largest subgraph that conects to vertex $1$ which only contains $1$ and
$3$ colored vertices (it can have other colors hanging off of it). Now, if it
doesn't contain $v_3$ then we can flip the color each of the vertices' of the
sub graph (i.e. every $1$ colored vertex becomes a $3$ colored vertex). And then
we can just color $w$ $1$ because it will have 2 vertices of color $3$ adjacent
to it and no vertices of color $1$ now.

Thus, we can assume that there is an unbroken path from $v_1$ to $v_3$ which
contains only $1$ and $3$ colored vertices. Now, we can apply the same exact
logic to the colors $2$ and $4$. Thus, we only care about the case when there
is unbroken path from $v_2$ to $v_4$, as otherwise we can just flip the colors
fo the subgraph coming from $v_2$ to recolor $w$ with color $2$. However, there
can't be both an unbroken path from $v_1$ to $v_3$ using only $1$ and $3$
colored vertices, *and* an unbroken path from $v_2$ to $v_4$ using only $2$ and
$4$ colored vertices. The paths have to cross because they are paths on a plane.
This that case leads to contradiction, so any planar graph must've fallen into
one of the cases that was 5 colorable. Thus, every planar graph is 5 colorable.

$$\tag*{$\Box$}$$
