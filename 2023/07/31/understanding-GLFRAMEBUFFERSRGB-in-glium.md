+++
title = "Colorspace in glium"
date = Date("2023/07/31", "yyyy/mm/dd")
rss = ""
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

I have been working on a small project to learn [OpenGL](/404). I decided to use Rust since it is the best programming language ever conceived by man. The obvious choice for an OpenGL project in Rust is to use [`glium`](https://github.com/glium/glium/). However, I found their API a little confusing. I thought it would be useful to have a guide on how to deal with colorspaces in `glium` and OpenGL. This is that guide. **Note: This is my first foray into graphics, if anything is wrong, or hints at a misunderstanding on my part, please let me know.**

# Concepts involved

- `GL_FRAMEBUFFER_SRGB`: A global parameter, associated with an OpenGL context. It comes up so much, I will refer to it as `GFS`. How it affects gamma correction is explained in the [Summary of literature](/2023/07/31/understanding-GLFRAMEBUFFERSRGB-in-glium/#summary_of_literature).
- Texture: a place to store image data/raster graphics (pixel values)
    - can come in 2 variants: regular and sRGB
    - can be used as a render target (in which case the texture will be attached on an FBO, mentioned below) or as a source of image data
- Framebuffer: a collection of buffers used as a destination for rendering. Can be the Default Framebuffer or a user-created Framebuffer Object (FBO).

# "help my colors are broken" flowchart (for the current glium way)

Many of the issues people have encountered would be solved by this flow chart, so I've included it before the rest of my learnings.

@@im-most
![](/assets/help-colors.jpg)
@@

# Summary of literature

Normally, color values in images are assumed to be in linear color space. If an image is in sRGB color format (ie. `SrgbTexture2d` vs `Texture2d`), values are assumed to be stored in sRGB.

"When fetching from sRGB images in shaders, values are converted from sRGB into linear colorspace." Thus, the shader only sees linear values.

If OpenGL needs to filter sampled values, the implementation is allowed to filter before or after the sRGB conversion (and since filtering is linear, you want it to happen in a linear space (ie. linear RGB)).

[source](https://www.khronos.org/opengl/wiki/Image_Format)

"Normally, sRGB images perform color correction, such that texture reads from them will always convert to linear [RGB]".

When writing from a fragment shader, we need to know how to interpret the values written by the shader. If the output buffer is linear RGB, we assume the answer is linear. But if we're writing to an sRGB image, maybe we want to write linear or sRGB. For this, we need a global toggle since the gamma correction partly depends on the output buffer. This is the `GFS` parameter.

When `GFS` is:
- disabled: assume the output buffer is the same color space as input buffer (we assume the user knows what they're doing)
- enabled: if destination is[^2]
	- sRGB: assume shader output is linear, so it converts linear RGB to sRGB
	- non-sRGB: no conversion

[^2]: you can check this with `glGetFramebufferAttachmentParameter(GL_Framebuffer_SRGB)`

Blending is a linear operation, so we need to convert to linear, then back to sRGB. If `GFS` is enabled, if a destination image is sRGB, the color will be converted to linear, blended w/ linear source and convert back. If `GFS` is disabled, "we assume the user knows what they are doing"; thus, "blending against an sRGB image will not perform any correction. This is usually not a good idea even if you are writing sRGB color values from the Fragment Shader."

[source](https://www.khronos.org/opengl/wiki/Framebuffer)

This entire section is summarized by this graphic: 

@@im-full
![](/assets/gpu-colorspace.jpg)
@@

# `clear_color()` vs `clear_color_srgb()`

If you call `clear_color_srgb()`, we enable `GFS` and record that in the global context if it wasn't already enabled. If you call `clear_color()`, we disable `GFS`  (and record that in the global context) if it wasn't already.

source: (`commit:filename:line-number)` `5d50e70:src/ops/clear.rs:38`

# Github Issues

- `#2059`: my issue, which this post hopefully addresses
- `#1466`: requests a feature for `SrgbTexture2d` that `Texture2d` has
- `#1414`: a misunderstanding
- `#1185`: glutin issue
- `#987`: created the `clear_color`–`clear_color_srgb` distinction

## Issue `#1793`

- Setting `srgb=true` in `ContextBuilder` fixes the problem
- claim: textures have sRGB and non-sRGB variants, so global context is not important

## Issue `#1615`

- fix the problem with `program!()` macro in `src/macros.rs` using `let ___outputs_srgb: bool=false`
- both variants of the `ProgramCreationInput` enum have `outputs_srgb` flags, and you can pass one of them to `Program::new()` to have direct control if you're not using `program!()` *(this is what I ended up fixing `#2059`, my issue, but I didn't understand it at the time)*

## Issue `#805`

- some systems don't support `GFS` well, so it needs to be able to be disabled
- rendering your image to an `SrgbTexture2d` instead of `Texture2d` fixes the problem
- fix: a flag is available to `Program::new()` to turn it on and off *the same solution as `#1615` and `#2059` (mine)*

# What should we do?

We can either hide the fact that OpenGL uses `GFS`, or we should be very transparent about what `GFS` means and how to interact with it.

## Transparent Approach

Here, `GFS` should be enabled or disabled when the context is initialized and never changed (there is already support for this in `ContextBuilder`). Using `clear_color()` to change the `GFS` value seems like the wrong way to go since it introduces unnecessary complexity. I can't think of a use case where being able to change `GFS` at runtime is useful if we're trying to be transparent (feel free to point one out in the comments).

In this approach with `GFS` enabled, we still require users to use `SrgbTexture`s and `Texture`s, and to differentiate what type of values are stored there. But, there is no need to specify whether a program outputs sRGB, since we are going to use OpenGL's underlying implicit conversions.

In this approach, if you choose to disable `GFS`: 
- you should do everything using linear RGB and no gamma correction will be applied (except from `SrgbTexture`, which will of course be converted to linear when sampled from)
- we assume the user understands what they are doing

### How to implement this approach

First, remove `clear_color_srgb()` and don't fiddle with `GFS` in `clear_color()`. Second, remove the code which enables `GFS` in `use_program()` at `5d50e70:src/program/program.rs:449`.

### Advantages of this approach

- familiarity: it respects the OpenGL model (using `GFS` as a global parameter) and obeys the [principle of least astonishment](https://en.wikipedia.org/wiki/Principle_of_least_astonishment) 
- easy-of-use for beginners assuming they already understand OpenGL

### Disadvantages

- blending with an sRGB image won't work nicely with `GFS` disabled, so all data must be in linear color space, which is mildly inconvenient

## Hidden approach

The user should never have to worry about `GFS`. This is most similar to how things are done now. They do still need to worry about whether their textures and programs contain/output sRGB values.

### How to implement this approach

We shouldn't let users choose the `GFS` setting when initializing a context since they shouldn't worry about it. And `GFS` should always be enabled. We will still need users to tell us whether they're texture has linear or sRGB values, and whether their program outputs linear or sRGB. But, that is the only time they'll need to worry about colorspace, we'll handle the enabling/disabling of `GFS` behind the scenes (similar to how we do it in `use_program()` at `5d50e70:src/program/program.rs:449`).

We also should remove `clear_color_srgb()` since users shouldn't worry about `GFS`.

### Advantage of this approach

- simplicity: there's only 1 mode to worry about
- backward compatibility with old `glium` programs since this is doesn't change the fundamental model

{{ addcomments }}
