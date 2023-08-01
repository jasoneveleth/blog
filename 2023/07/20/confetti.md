+++
title = "Confetti"
date = Date("2023/07/20", "yyyy/mm/dd")
rss = ""
tags = ["website"]
+++
~~~
<details>
<summary>Table of Contents</summary>
~~~
\toc
~~~
</details>
~~~

# Overview

I took computer vision many years ago, and I wanted to refresh my knowledge of camera matrices and rendering. So I created [this website](https://www.jasoneveleth.com/confetti) that displays an infinite stream of confetti. It calculates the movement of confetti in real-time. The code can be found [here](https://github.com/jasoneveleth/confetti).

# Design

I wanted physics and camera matrices to be the focus of the project, so the UI is spartan.

To describe what is happening, we will assume that in the world, $x,y,z$ are arranged as if we're looking at an $x$-$y$ graph, and $z$ is coming toward us:

![](/assets/axes.png)

We need to convert a point in that, to a point on the screen, which has coordinates $(0,0)$ in the top left, and increasing $x$ and $y$ going down and right. We can do that using `Rt`, which is the extrinsic matrix: $$[R\mid t]=\begin{bmatrix}1&0&0&t_x\\ 0&1&0&t_y\\ 0&0&1&t_z\end{bmatrix}.$$
This matrix describes how the camera is positioned in relation to the origin. Our rotation is the identity, and our translation is $10$ in the $z$ direction (since our camera is oriented normally at $(0,0,-10)$). Left multiplying this with a vector will move it 10 units in the $z$ direction (bringing the camera to the origin).

The second matrix we need is the intrinsic matrix: $$K=\begin{bmatrix}f_x&s&u\\ 0&f_x&v\\ 0&0&s\end{bmatrix}.$$
$f_x, f_y$ are the focal length in pixels of the camera. $u,v$ are the principle point offset (shift in the sensor inside the camera). $s$ is skew. For us, $f_x=f_y=\max(w, h)/2$, which is the maximum of the width and height of the screen. Our skew is 1, and our principle point offsets are 0.

The `index.js` file holds most of the code, and `math.js` has some utility functions (like matrix multiplication). There is one function I want to highlight in `math.js`, and that is `world2image`. It converts world coordinates to image coordinates. It multiplies $K \cdot [R\mid t] \cdot c$, where $c$ is the world coordinates and rescales the $x,y$ values by $z$. The `KRt` matrix is a precomputed multiplication and will take a point in 3D and convert it to an $x,y$ coordinate system which is what the camera sees. Finally, we convert the $x,y$ coordinates to screen coordinates.

With the camera matrix calculation out of the way, let's dig into the implementation. I keep track of confetti using its center (in world coordinates), velocity, acceleration, its two rotation parameters $\theta$ and $\phi$. I used a constant acceleration down at $-9.81$ (for obvious reasons). I initialize the position to be the center of the screen (the origin). I initialize the velocity uniformly random from the top quadrant of a circle. I initialize the rotation parameters, and their deltas randomly.

The main approach is to keep a big array of confetti, and on each rendering step:
- replace confetti that falls off-screen
- we update the world coordinates of each confetti (using acceleration, velocity, delta rotations, etc.)
- extract the corners of each confetti given their orientation
- use `world2image` to get the image coordinates of those corners
- draw the quadrilaterals from those image coordinates.

It is calculating how each confetti would fall in real-time, and thus, large amounts of confetti (or badly optimized browsers), can really slow down a machine.

Overall, I really enjoyed this project.
{{ addcomments }}
