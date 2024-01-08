+++
title = "A Linear Algebra Perspective on High School Chemistry"
date = Date("2023/12/08", "yyyy/mm/dd")
rss = "My attempt to understand what happened in high school with the tools of linear algebra."
tags = String[]
+++
~~~
<details>
<summary>Table of Contents</summary>
~~~
\toc
~~~
</details>
~~~

Recently, I was on a ski trip and the topic of chemistry came up, and I realized that high school stoichiometry seemed like a algorithm I should recognize.

In stoichiometry, you're given an equation like this: $$x_1C_6H_{12}O_6 + x_2O_2 = x_3H_2O + x_4CO_2.$$
We're trying to determine what the coefficients need to be for the equation to be balanced. From what I remember from high school, you just think really hard until you figure out what they need to be, and that's how you determine the coefficients.

Taking a more systematic approach, we can move everything over to the other side, giving
$$x_1C_6H_{12}O_6 + x_2O_2 - x_3H_2O - x_4CO_2 = 0$$

We can consider the balance for each element as an equation, and our coefficients as unknowns
$$
\begin{align*}
C & &6x_1 + 0x_2 - 0x_3 - 1x_4 = 0\\
H & &12x_1 + 0x_2 - 2x_3 - 0x_4 = 0\\
O & &6x_1 + 2x_2 - 1x_3 - 2x_4 = 0\\
\end{align*}
$$

Now it's just a problem of Gaussian elimination. This is a homogeneous linear system:

$$
\begin{bmatrix}
6 & 0 & 0 & -1\\
12 & 0 & -2 & 0\\
6 & 2 & -1 & -2\\
\end{bmatrix}
\begin{bmatrix}
x_1\\
x_2\\
x_3\\
x_4\\
\end{bmatrix}
= \begin{bmatrix}
0\\0\\0\\
\end{bmatrix}.
$$
This is so exciting, because now you can use your favorite linear solver on this equation to determine the balance for the original equation.

{{ addcomments }}
