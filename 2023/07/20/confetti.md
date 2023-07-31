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

This website displays an infinite stream of confetti. It calculates the movement of confetti in real-time.

# Problem

I took computer vision many years ago, and I wanted to refresh my knowledge of camera matrices and rendering.

# Design

I wanted physics to be the focus of the project, so the UI is spartan. 

The `index.js` holds most of the code, and `math.js` has some utility functions (like matrix multiplication). There is one function I want to highlight in `math.js`, and that is `world2image`. It converts world coordinates to image coordinates. We will assume that in the world, $x,y,z$ are arranged as if we're looking at an $x$-$y$ graph, and $z$ is coming toward us:

```
^  y
|
|
|
*-------> x
z
```

We are pretending we have a camera 

It is calculating how each confetti would fall in real-time, and thus, large amounts of confetti (or badly optimized browsers), can really slow down a machine.

The source is on [github](https://github.com/jasoneveleth/confetti).

# What I learned

{{ addcomments }}
