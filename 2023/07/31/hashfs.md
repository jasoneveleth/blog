+++
title = "hashfs"
date = Date("2023/07/31", "yyyy/mm/dd")
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

This weekend I was helping my aunt make sure that her files were syncing correctly between two laptops. I'd been thinking about git a lot, and I realized recursive hashing was the way to go.

The problem I was trying to solve was making comparisons between two directory trees easy. The solution I came up with was to use the sha256 digest of file contents to represent files. This prevents us from having to look at the file contents, and the comparison between two files is easy since the digests are just numbers. We can use the hash of all the files in the directory to represent a directory. So, to compare if two directories are identical, we just need to look at the digests that represent them. This solves the problem because now it is easy to see which parts of a directory tree are the same.

It remains to figure out how to display this information. I've been working with HTML a lot recently working on this blog, and I realized a `<details>` element is the perfect fit. It hides the contents unless you click on it, so you don't need to look at the files which have the same hashes. And, we can nest `<details>` elements to create a tree that mirrors the directory structure.

I choose to write this up in Rust since I love Rust. The code can be found on [github](https://github.com/jasoneveleth/hashfs).

This utility ended up not being useful since iCloud automatically frees up space by replacing files with a `file.ext.icloud` file, which ruins the whole hashing system. Regardless, I am very proud of it, and I think it could be useful to others.

{{ addcomments }}
