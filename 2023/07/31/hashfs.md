+++
title = "hashfs"
date = Date("2023/07/31", "yyyy/mm/dd")
rss = ""
tags = ["website"]
+++
~~~
<details class="toc">
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

# In action

For a directory tree like:
```
b
|- a.txt
|- b.txt
|- c.txt
|- d.txt
|- e.txt
|- f.txt
|- g.txt
|- j.txt
```
It would produce this (hashes have been elided for space):
~~~
<details class="d"><summary class="s">
<strong>b</strong> 7a9b89fa674b0b703eaafca2e79e474a55...
</summary>
<strong>a.txt</strong> 86bfc753650b4b730b7177b9e665dbe100...</br>
<strong>b.txt</strong> 86bfc753650b4b730b7177b9e665dbe100...</br>
<strong>c.txt</strong> a380d5f755183c7c0f05a327e7094c9e98...</br>
<strong>d.txt</strong> a380d5f755183c7c0f05a327e7094c9e98...</br>
<strong>e.txt</strong> 5c836f02b0d2653274fefab5e108d3e78c...</br>
<strong>f.txt</strong> ecef6bf3c9100c87aaeb4fae46b23f23d6...</br>
<strong>g.txt</strong> 9d1af65406716fd984b640f7f24b43ccd6...</br>
<strong>j.txt</strong> 79a2f595545dd08b508c2a808e543befcb...</br>
</details><style>:root{--l: 25px}details > details{margin-left: var(--l);}.s{margin-left: calc(0px - var(--l))}.d{font-family: monospace;margin-left: var(--l);font-size: 70%;}details > strong{font-weight: 700;}</style>
~~~

# Update 8/9/2023

One of my friends let me know that I have implemented a [Merkle tree](https://en.wikipedia.org/wiki/Merkle_tree). Merkle trees are trees whose leaves store the hash of their contents, and whose interior nodes store the hashes of their children. 

They are often used in cryptocurrencies because you can prove the inclusion of a leaf in the tree by just providing the child nodes corresponding to the path from that leaf to the root. This works in log time because the tree is $log(N)$ tall.

{{ addcomments }}
