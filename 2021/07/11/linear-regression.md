+++
title = "Linear Regression"
date = Date("2021/07/11", "yyyy/mm/dd")
rss = ""
tags = ["math"]
+++
~~~
<details>
<summary>Table of Contents</summary>
~~~
\toc
~~~
</details>
~~~

# Theory

We are trying to find the line of best fit given a collection of coordinates. 
For example, $\{(x_1, y_1), (x_2,y_2), (x_3, y_3), \dots\}$. We would like to
find $m,b$ such that $y = mx + b$ minimizes the sum of the residuals squared. By
that I mean we want to minimize a function $L(\alpha) = \sum_i (y_i - (mx_i + b))^2$, by
finding the best $m$ and $b$.

We will use the notation from [here](/2021/07/11/calculus-notation). Here are some fun facts we'll need to know:
1. $\sum_i x_i^2 =\lVert x \rVert^2$
2. $\lVert x \rVert^2 = x^Tx$
3.  $(A + B)^T = A^T + B^T$ and $(AB)=B^TA^T$.
4. $D ( u^Tx) = u^T$, $D (x^Tu) = u^T$, and $D(x^Tx) = D(\bar{x}^Tx) + D(x^T\bar{x})$.[^1]

We need to set up some definitions. Let
$$y = \begin{bmatrix}y_1\\y_2\\y_3\\y_4\\\vdots\end{bmatrix},
X = \begin{bmatrix}x_1 & 1\\x_2 & 1\\x_3 & 1\\x_4 & 1\\\vdots & \vdots\end{bmatrix},
\alpha = \begin{bmatrix}m\\b\end{bmatrix}.$$

So our goal is:

$$\underset{\alpha}{\text{argmin}}\, L(\alpha)$$
$$=\underset{\alpha}{\text{argmin}}\, \sum ((y_i) - (m x_i + b))^2$$
Apply fun fact number #1:
$$=\underset{\alpha}{\text{argmin}}\, \left\lVert \begin{bmatrix}(y_1 - (m x_1 + b))\\ (y_2 - (m x_2 + b))\\ (y_3 - (m x_3 + b))\\ (y_4 - (m x_4 + b))\\ \vdots\end{bmatrix}\right\rVert^2$$
$$=\underset{\alpha}{\text{argmin}}\, \lVert y - X\alpha\rVert^2$$
Apply fun fact #2:
$$=\underset{\alpha}{\text{argmin}}\, (y-X\alpha)^T(y - X\alpha)$$
Apply fun fact #3:
$$=\underset{\alpha}{\text{argmin}}\, (y^T - \alpha^TX^T)(y - X\alpha)$$
$$=\underset{\alpha}{\text{argmin}}\, y^Ty - \alpha^TX^Ty - y^TX\alpha + \alpha^TX^TX\alpha$$

To minimize this, we find the critical points of the function. We do this by finding where
the derivative of $L$ with respect to $\alpha$ is $0$.

$$
\begin{align*}
0 &= L'(\alpha)\\
&= D (y^Ty - \alpha^TX^Ty - y^TX\alpha + \alpha^TX^TX\alpha)\\
&=D (y^Ty) - D (\alpha^TX^Ty) - D (y^TX\alpha) + D (\alpha^TX^TX\alpha)\\
\end{align*}$$
Apply fun fact #4:
$$
\begin{align*}
&= 0 - (X^Ty)^T - y^TX + D (\alpha^TX^TX\bar{\alpha}) + D (\bar{\alpha}^TX^TX\alpha)\\
&= -y^TX - y^TX + (X^TX\alpha)^T + \alpha^TX^TX\\
&=-2y^TX + \alpha^T(X^TX)^T + \alpha^TX^TX\\
&=-2y^TX + \alpha^TX^TX + \alpha^TX^TX\\
&=-2y^TX + 2\alpha^TX^TX\\
\end{align*}
$$

And now for the glorious part (who am I kidding, this whole thing has been
glorious),

$$2y^TX=2\alpha^TX^TX$$
$$X^Ty=(X^TX)\alpha$$
$$(X^TX)^{-1}X^Ty = \alpha = \begin{bmatrix}m & b\end{bmatrix}$$

# Examples

Say we are given this set of coordinates: $\{(1.3, 0.8), (3.2, 3.5), (5.6, 6.4), (8.5, 7.7)\}$. Then we can either do the arithmetic by hand (from the last equation) or open `julia` and give it the vectors (some output omitted):
```julia
julia> y = [0.8; 3.5; 6.4; 7.7]
julia> X = [1.3 1; 3.2 1; 5.6 1; 8.5 1]
julia> inv(X' * X) * X' * y
2-element Vector{Float64}:
 0.9628
 0.1228
```

Which gives us our desired line of best fit: $y = 0.962823x + 0.122874$.



[^1]: The bar in $\bar{\alpha}$ or $\bar{x}$ means treat it as a constant, in the same way, that you would if you were doing the product rule with single-valued functions: $D(f(x)g(x)) = D(f(x)\bar{g}(x)) + D(\bar{f}(x) g(x)) = (Df(x))g(x) + (Dg(x))f(x)$.


{{ addcomments }}
