<!--
Add here global page variables to use throughout your website.
-->
+++
author = "Jason Eveleth"

# Add here files or directories that should be ignored by Franklin, otherwise
# these files might be copied and, if markdown, processed by Franklin which
# you might not want. Indicate directories by ending the name with a `/`.
# Base files such as LICENSE.md and README.md are ignored by default.
ignore = ["node_modules/"]

# RSS (the website_{title, descr, url} must be defined to get RSS)
generate_rss = true
website_title = "Jason's Blog"
website_descr = "A blog on whatever I'm thinking about."
website_url   = "https://www.jasoneveleth.com/blog"

prepath = "blog"

# table of contents levels
mintoclevel = 1
maxtoclevel = 3
+++

<!--
Add here global latex commands to use throughout your pages.
-->
\newcommand{\R}{\mathbb R}
\newcommand{\scal}[1]{\langle #1 \rangle}
