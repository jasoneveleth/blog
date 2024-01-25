+++
title = "Hilarious Random Number Generator"
date = Date("2023/07/18", "yyyy/mm/dd")
rss = ""
tags = String[]
descr = true
githubsource = "https://github.com/jasoneveleth/blog/blob/dev/2023/07/18/chicken-coop-website.md"
+++
~~~
<details class="toc">
<summary>Table of Contents</summary>
~~~
\toc
~~~
</details>
~~~

I was searching for a chicken coop (as one does). I stumbled across a Facebook marketplace ad:

@@im-most
![](/assets/1story.png)
@@

The website it linked to had a live updating "people viewing this item" count:

@@im-most
![](/assets/2story.png)
@@

That seemed suspicious, so I looked into it.

@@im-most
![](/assets/3story.png)
@@

@@im-most
![](/assets/4story.png)
@@

They were just setting a random integer with jquery on a `setTimeout()`.


{{ addcomments }}
