import URIs
import Base64
import Base.Filesystem

struct Post
    name::String
    date::String
    title::String
    tags::Vector{String}
    rss::String
end

const posts = [
    # NEWEST TO OLDESTS
    Post("autograd", "2024/01/05", "A Rigorous (and Not-So-Rigorous) Look at JAX's Autograd", [], "My attempt to understand how JAX does autograd."),
    Post("stoichiometry", "2023/12/08", "A Linear Algebra Perspective on High School Chemistry", [], "My attempt to understand what happened in high school with the tools of linear algebra."),
    Post("professor chan's band coloring", "2023/11/16", "Professor Chan's Band Coloring", [], "My recollection of my advisor's graph theory application from freshman year."),
    Post("purely functional dijkstras", "2023/11/05", "Asymptotic Analysis of Dijkstras in Haskell", [], "My analysis of whether it is possible to have optimal* Dijkstras in Haskell"),
    Post("wave equation", "2023/08/01", "Wave equation simulation", ["website"], ""),
    Post("hashfs", "2023/07/31", "hashfs", ["website"], ""),
    Post("understanding GLFRAMEBUFFERSRGB in glium", "2023/07/31", "Colorspace in glium", [], ""),
    Post("voronoi blog post", "2023/07/20", "Voronoi Diagrams", ["website"], ""),
    Post("confetti", "2023/07/20", "Confetti", ["website"], ""),
    Post("why a blog", "2023/07/20", "Why a Blog?", ["website"], ""),
    Post("chicken coop website", "2023/07/18", "Hilarious Random Number Generator", [], ""),
    Post("bayes rule", "2023/07/17", "Bayes' Rule (in real life)", ["math"], ""),
    Post("picks theorem", "2021/09/03", "Pick's Theorem", ["math"], "Pick's Theorem is a formula for the area of a closed polygon with integer vertices.", ),
    Post("five color theorem",  "2021/07/16", "Five Color Theorem", ["math"], "The Five Color Theorem asserts that no planar graphs are 5-colorable.", ),
    Post("linear regression", "2021/07/11", "Linear Regression", ["math"], ""),
]

const notes_dir = "/users/jason/notes/"

function frontmatter(post)
    """+++
    title = "$(post.title)"
    date = Date("$(post.date)", "yyyy/mm/dd")
    rss = "$(post.rss)"
    tags = $(post.tags)
    descr = true
    +++
    ~~~
    <details class="toc">
    <summary>Table of Contents</summary>
    ~~~
    \\toc
    ~~~
    </details>
    ~~~
    """
end

function resolve_post_title(title)
    for post in posts
        if post.name == title
            return post2filename(post)
        end
    end
    "404"
end

function remove_existing!()
    # all years are 20xx, I want to make my own millenium problem
    existing_folders = filter(x -> x[1:2] == "20", readdir("."))
    if length(existing_folders) == 0
        return
    end
    println("Existing folders:")
    println(existing_folders)
    println("Is it okay to delete these (y/n): ")
    response = readline(stdin)[1]
    if response != 'y'
        println("exiting")
        return
    end
    for path in existing_folders
        Filesystem.rm(path, recursive=true)
    end
end

function post2filename(p)
    p.date * "/" * escape_uri(p.name)
end

function filepaths_and_frontmatter(posts_list)::Vector{Tuple{String, String, String}}
    ret = []
    for p in posts_list
        src = notes_dir * p.name * ".md"
        dest = post2filename(p) * ".md"
        push!(ret, (src, dest, frontmatter(p)))
    end
    ret
end

function escape_uri(str)
    URIs.escapeuri(replace(str, " " => "-", "'" => ""))
end

function process_file(file_contents)
    # we can't use replace(s, regex => substituionstr ) because we 
    # need the capture group to be evaluated before we URI encode it
    # replace() assumes that the second part of the pair is a string
    # so there's no way to arrange the computation such that the URI encode 
    # happens after the capture

    function f(m)
        link_name, section, alias = m.captures
        if alias !== nothing
            alias = alias[2:end] # cut off '|'
        end
        if section !== nothing
            section = section[2:end] # cut off '#'
        end
        s = ""

        # display
        if alias !== nothing
            s *= "[$(alias)]"
        elseif section !== nothing
            s *= "[$(section)]"
        else
            s *= "[$(link_name)]"
        end

        # href
        if section !== nothing
            s *= "(/$(resolve_post_title(link_name))/#$(replace(lowercase(section), ' ' => '_')))"
        else
            s *= "(/$(resolve_post_title(link_name)))"
        end
        s
    end

    function g(m)
        note_name = m.captures[1]
        included_text = read(notes_dir * note_name * ".md", String)

        # TODO: this function won't work for recursive includes, we 
        # want to recurse, but we can't call process_file() since we 
        # only want to do the other substitutions once (once all of the
        # file has been assembled)
        @assert match(r"\!\[\[([a-zA-Z0-9 .'=!-]+)\]\]", included_text) === nothing

        included_text
    end

    function dotsrc2imgsrc(m)
        text = m.captures[1]
        inpath, io = mktemp()
        write(io, text)
        close(io)
        outpath, io = mktemp()
        close(io)
        run(pipeline(inpath, `dot -Tpng -Gdpi=300`, `base64`, outpath))

        "![](data:image/png;base64,$(read(outpath, String)))"
    end

    function tikzsrc2imgsrc(m)
        text = m.captures[1]
        inpath, io = mktemp()
        write(io, "\\documentclass[tikz,border=2mm]{standalone}\n")
        write(io, text)
        write(io, "\n")
        close(io)
        outpath, io = mktemp()
        close(io)
        run(pipeline(inpath, `pwrap pdflatex -interaction batchmode -halt-on-error file.tex tex pdf`, `convert -density 300 pdf:- png:-`, `pwrap mogrify -strip file.png png png`, `base64`, outpath))

        "![](data:image/png;base64,$(read(outpath, String)))"
    end

    # change `mathbfit` to `bm`
    file_contents = replace(file_contents, r"\\mathbfit" => "\\bm")


    # note inclusion: ![[note]]
    rx = r"\!\[\[([a-zA-Z0-9 .'=!-]+)\]\]"
    file_contents = replace(file_contents, rx => s -> g(match(rx, s)))

    # wikilinks: [[link name#section|alias]] => [alias](/2021/07/11/link-name/#section)
    #            [[link name|alias]] => [alias](/2021/07/11/link-name)
    #            [[link name#section]] => [section](/2021/07/11/link-name/#section)
    #            [[link name]] => [link name](/2021/07/11/link-name/)
    rx = r"\[\[([a-zA-Z0-9 .'=!-]+)(#[a-zA-Z0-9 ()]+)?(\|[a-zA-Z0-9 ]+)?\]\]"
    file_contents = replace(file_contents, rx => s -> f(match(rx, s)))

    # convert images
    # ![stuff](images/something) => ![stuff](/assets/something)
    rx = r"!\[([a-zA-Z0-9 .'-=!|]*)\]\(images/([a-zA-Z0-9 .'_=!-]+)\)"
    file_contents = replace(file_contents, rx => s"![\1](/assets/\2)")

    # videos
    # ![stuff](videos/something) => ~~~\n<videos>stuff](/assets/something)</video>\n~~~
    rx = r"!\[([a-zA-Z0-9 .'-=!|]*)\]\(videos/([a-zA-Z0-9 .'_=!-]+)\)"
    file_contents = replace(file_contents, rx => s"~~~\n<video controls src=\"/assets/\2\" alt=\"\1\"></video>\n~~~")

    # remove `dot` code block
    rx = r"```dot\n([^`]*)\n```"
    file_contents = replace(file_contents, rx => s -> dotsrc2imgsrc(match(rx, s)))

    # remove `tikz` code block
    rx = r"```tikz\n([^`]*)\n```"
    file_contents = replace(file_contents, rx => s -> tikzsrc2imgsrc(match(rx, s)))
end

function copy_images!(file_contents)
    # images: ![](images/file-path.jpg)
    rx = r"!\[[a-zA-Z0-9 .'=!-|]*\]\(/assets/([a-zA-Z0-9 .'_=!-]+)\)"
    for m in eachmatch(rx, file_contents)
        x = m.captures[1]
        if !isfile("_assets/$(x)")
            cp(notes_dir * "images/$(x)", "_assets/$(x)")
        end
    end
end

function make_space!(file_path)
    directory_path = dirname(file_path)
    mkpath(directory_path)
end

function make_contents(note_contents, frontmatter)
    """
    $(frontmatter)
    $(process_file(note_contents))

    {{ addcomments }}
    """
end

function copy_files!(data::Vector{Tuple{String, String, String}})
    for (src, dest, frontmatter) in data
        newcontent = make_contents(read(src, String), frontmatter)

        make_space!(dest)
        overwrite_if_diff!(dest, newcontent)
        copy_images!(newcontent)
    end
end

function overwrite_if_diff!(file_path, content)
    if isfile(file_path) && read(file_path, String) == content
        println("skipped: ", file_path)
    else
        write(file_path, content)
        println("written ", file_path)
    end
end

function get_posts(posts, year)
    for p in posts
        if p.date[1:4] == year

        end
    end
end

function new_index!()
    index = """
    @def title = "Archive"

    """

    f(l, x) = push!(l, x.date[1:4])
    years = unique(foldl(f, posts, init=[]))
    for y in years
        index *= "## $(y)\n"
        for p in filter(x-> x.date[1:4] == y, posts)
            index *= "~~~<span class='date'>$(p.date[6:end])</span>~~~ [$(p.title)]($(p.date)/$(escape_uri(p.name)))\n\n"
        end
    end
    overwrite_if_diff!("index.md", index)
end

function new_search!()
    search = """
    @def title = "Search"

    ~~~
    <script>
    const mystuff = [
    """
    for p in posts
        contents = read(post2filename(p) * ".md", String)
        contents = replace(contents, "\\" => "\\\\")
        contents = replace(contents, "\"" => "\\\"")
        contents = replace(contents, "~~~" => "")
        contents = replace(contents, r"\+\+\+[^+]*\+\+\+" => "")
        contents = replace(contents, "```" => "")
        contents = replace(contents, "\n" => " ")
        contents = replace(contents, r"!\[\]\(data:image/png;base64,[-A-Za-z0-9+/]*=* \)" => "")
        # this is the beginning of every document: "  <details> <summary>Table of Contents</summary>  \\toc  </details>   "
        contents = contents[70:end]
        search *= "{title: \"$(p.title)\", content: \"$(contents)\"},\n"
    end
    search *= """
    ]
    </script>
    <input oninput="search(this.value, mystuff)"/>
    <div id="results-div"></div>
    ~~~
    """
    overwrite_if_diff!("search.md", search)
end

function main()
    println("syncing...")
    data = filepaths_and_frontmatter(posts)
    for (src, _, _) in data
        if !isfile(src)
            println("not found: ", src)
            return 1
        end
    end
    # remove_existing!()
    copy_files!(data)

    new_index!()
    new_search!()
end

main()
