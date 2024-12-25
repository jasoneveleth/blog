+++
title = "Animating a list shuffle with the FLIP technique"
date = Date("2024/12/25", "yyyy/mm/dd")
rss = "Explaining how to use the FLIP technique to animate a list shuffle"
tags = String[]
descr = true
githubsource = "https://github.com/jasoneveleth/blog/blob/dev/2024/12/25/animating-list-shuffle-with-FLIP-technique.md"
+++
~~~
<details class="toc">
<summary>Table of Contents</summary>
~~~
\toc
~~~
</details>
~~~

### What is the FLIP technique?

FLIP stands for First Last Invert Play. It's a technique for easily animating objects that are moving around. You record the **first** position of the object, and the **last** position of your object (after the animation), then **invert** the object's position to the first position using a transformation. Finally, **"play"** an animation which transitions the object's position from the inverted transform to the identity transform.

[This article](https://css-tricks.com/animating-layouts-with-the-flip-technique/) by css tricks has the best explanation I've found. The css tricks article links to the original article [here](https://aerotwist.com/blog/flip-your-animations/). I found [two](https://medium.com/developers-writing/animating-the-unanimatable-1346a5aab3cd) [articles](https://www.taraojo.com/post/animating-element-reordering) showing how to integrate it into React's framework but nothing about vanilla html/js.
### Why I chose vanilla html/js

I chose to use vanilla html/js instead of React since I was auto-generating the html content and I didn't want to have to deal with the dependency of React. I found that chatGPT couldn't write correct code snippets using vanilla js, which indicated to me that there aren't many examples on the web.

It was a lot of trial and error to figure out how the browser schedules animation frames and when to change the style on each element. It turns out the best way to do it is rearrange all the elements on the DOM. Then, in a `requestAnimationFrame` thunk, do the inversion (animate them to their old positions with 0ms transition). Next, force the browser to do the animation with `void container.offsetHeight;` (which is browser magic). Then play them by setting their transform to nothing with a transition of `300ms`.

The `get_val` function takes the item and converts it to a real number which we use for sorting. I chose to put the values I wanted to sort by as fields of the element (and so `getAttribute(data-${indexType})` correctly retrieves it). But, you could choose any implementation/storage for the sorting keys.

If we're willing to treat the `void container.offsetHeight;` as a black box then everything should make sense. My guess is that if you ask for the offset height ([which is](https://developer.mozilla.org/en-US/docs/Web/API/HTMLElement/offsetHeight) a measurement in pixels of the element's CSS height, including any borders, padding, and horizontal scrollbars), then it will force the browser to move all the elements to their animated locations.

Below is the code. Replace the `...` placeholders with whatever data you want.

```html
<div class="container">
<details data-xvalue="186" data-idnumber="148">
  <summary>Item title</summary>
  <pre>...</pre>
</details>
...
</div>
<script>
function sortDetails(indexType) {
  // get a list of items to sort
  const container = document.querySelector('.container');
  const items = Array.from(container.children);

  // 1. FIRST
  const oldPositions = items.map(el => el.getBoundingClientRect());

  // rearrange the items on the div
  const get_val = (x => parseFloat(x.getAttribute(`data-${indexType}`)));
  const argsort = Array(items.length).fill(0).map((_, i) => i).sort((i, j) =>
    get_val(items[i]) - get_val(items[j])
  )
  argsort.forEach(i => container.appendChild(items[i]));

  // 2. LAST
  const newPositions = items.map(el => el.getBoundingClientRect());

  requestAnimationFrame(() => {
    // 3. INVERT
    items.forEach((el, i) => {
  	  const dx = oldPositions[i].left - newPositions[i].left
  	  const dy = oldPositions[i].top - newPositions[i].top
  	  el.style.transform = `translate(${dx}px, ${dy}px)`
  	  el.style.transition = 'none'
    })
    // force reflow
    void container.offsetHeight;

    // 4. PLAY (play animation to new position)
    items.forEach(el => {
  	  el.style.transform = ''
  	  el.style.transition = 'transform 300ms'
    })
  })
}
</script>
```



{{ addcomments }}
