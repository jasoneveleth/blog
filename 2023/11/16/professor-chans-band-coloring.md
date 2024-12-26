+++
title = "Professor Chan's Band Coloring"
date = Date("2023/11/16", "yyyy/mm/dd")
rss = "My recollection of my advisor's graph theory application from freshman year."
tags = String[]
descr = true
githubsource = "https://github.com/jasoneveleth/blog/blob/dev/2023/11/16/professor-chans-band-coloring.md"
+++
~~~
<details class="toc">
<summary>Table of Contents</summary>
~~~
\toc
~~~
</details>
~~~

My first-year undergraduate advisor wrote a small program to save her musical camp director hours of work. Keep in mind that this was 4 years ago, so the details are a little shaky. Her musical camp director had dozens of students, and each of them was in at least 1 band. The problem he was trying to solve was assigning student bands to time slots for practicing. The issue was that students could be in multiple bands but only in one timeslot at a time.

Let's make this problem concrete. Let's say you have 9 students numbered $1$ through $9$. Let's say you have 3 time slots 8am-9am, 9am-10am, and 10am-11am. The bands are labeled with letters $a=\{2,5,7,9\},b=\{6,7\},c=\{1,2,3\},d=\{3\},e=\{1,3,8,9\},f=\{4,7,8\}$. This example isn't too hard to schedule by hand, but it would be tricky if you had many more students and many more bands. A solution to this scheduling would look like: $a,d$ to 8am, $b,e$ to 9am, and $c,f$ to 10am. You can check that none of the students overlap in the same time slot.

Now, in comes the graph theory. We can turn this problem into a graph by letting each band be a vertex and each timeslot be a color. Let's say 8am is red, 9am is green, and 10am is blue. Here is the resulting graph:

@@im-half
![](data:image/png;base64,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
)
@@

I've drawn edges between bands that share students. The restriction of a valid coloring means that a student never has to be in the same time slot for two different bands.

This was a very elegant solution to the problem and she said that her code still runs and schedules the bands practice times to this day.

{{ addcomments }}