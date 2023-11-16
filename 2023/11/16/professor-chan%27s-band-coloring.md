+++
title = "Professor Chan's Band Coloring"
date = Date("2023/11/16", "yyyy/mm/dd")
rss = "My recollection of my advisor's graph theory application from freshman year."
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

My first-year undergraduate advisor wrote a small program to save her musical camp director hours of work. Keep in mind that this was 4 years ago so the details are a little shaky. Her musical camp director had dozens of students, and each of them was in at least 1 band. The problem he was trying to solve was assigning student bands to time slots for practicing. The issue was that students could be in multiple bands but only in one timeslot at a time.

Let's make this problem concrete. Let's say you have 9 students numbered $1$ through $9$. Let's say you have 3 time slots 8am-9am, 9am-10am, and 10am-11am. The bands are labeled with letters $a=\{2,5,7,9\},b=\{6,7\},c=\{1,2,3\},d=\{3\},e=\{1,3,8,9\},f=\{4,7,8\}$. This example isn't too hard to do by hand, but it would be tricky if you had many more students and many more bands.

To solve this, we can assign $a,d$ to 8am, $b,e$ to 9am, and $c,f$ to 10am. You can check that none of the students overlap in the same time slot.

Now, in comes the graph theory. We can turn this problem into a graph by letting each band be a vertex and each timeslot be a color. Let's say 8am is red, 9am is green, and 10am is blue. Here is the resulting graph:

```tikz
\usepackage{tikz}

\begin{document}
\begin{tikzpicture}[
	node distance=3.5cm,
]

\def\testarray{{"red", "green", "blue", "red", "green", "blue"}}

\foreach \v 
[evaluate={\x=2*cos((3-\v)*360/6)}, evaluate={\y=2*sin((3-\v)*360/6)}, evaluate={\letter=int(\v+96)}, evaluate={\mycolor=\testarray[\v-1]}]
in {1,...,6} 
\node[draw, circle, fill=\mycolor, font=\footnotesize] (node\v) at (\x, \y) {\char\letter};

\draw (node1) -- (node2) node[midway,above] {$7$};
\draw (node1) -- (node3) node[midway,right] {$2$};
\draw (node1) -- (node5) node[midway,right] {$9$};
\draw (node1) -- (node6) node[midway,right] {$7$};
\draw (node3) -- (node4) node[midway,right] {$3$};
\draw (node4) -- (node5) node[midway,below] {$3$};
\draw (node5) -- (node6) node[midway,below] {$8$};
\draw (node2) -- (node6) node[midway,right] {$7$};
\draw (node3) -- (node5) node[midway,right] {$1,3$};

\end{tikzpicture}
\end{document}
```

I've drawn edges between bands that share students. The restriction of a valid coloring means that a student never has to be in the same time slot for two different bands.

This was a very elegant solution to the problem and she said that her code still runs and schedules the bands practice times to this day.

{{ addcomments }}
