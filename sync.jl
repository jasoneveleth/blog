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

const notes_dir = "/users/jason/.root/notes/"

function frontmatter(post)
    """+++
    title = "$(post.title)"
    date = Date("$(post.date)", "yyyy/mm/dd")
    rss = "$(post.rss)"
    tags = $(post.tags)
    +++
    ~~~
    <details>
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
    URIs.escapeuri(replace(str, " " => "-"))
end

function process_file(file_contents)
    # we can't use replace(s, regex => substituionstr ) because we 
    # need the capture group to be evaluated before we URI encode it
    # replace() assumes that the second part of the pair is a string
    # so there's no way to arrange the computation such that the URI encode 
    # happens after the capture

    function f(m)
        x, y = m.captures
        if y === nothing
            "[$(x)](/$(resolve_post_title(x)))"
        else
            "[$(y)](/$(resolve_post_title(x)))"
        end
    end

    function h(m)
        x, y = m.captures
        "[$(y)](/$(resolve_post_title(x))/#$(replace(lowercase(y), ' ' => '_')))"
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
        run(pipeline(`dot -Tpng`, stdin=inpath, stdout=pipeline(`base64`, outpath)))

        "![](data:image/png;base64,$(read(outpath, String)))"
    end

    # note inclusion: ![[note]]
    rx = r"\!\[\[([a-zA-Z0-9 .'=!-]+)\]\]"
    file_contents = replace(file_contents, rx => s -> g(match(rx, s)))

    # section links: [[link name#section title]] => [section](/2021/07/11/link-name/#section)
    rx = r"\[\[([a-zA-Z0-9 .'=!-]+)#([a-zA-Z0-9 ]+)\]\]"
    file_contents = replace(file_contents, rx => s -> h(match(rx, s)))

    # wikilinks: [[link name|alias]] => [alias](/2021/07/11/link-name/)
    #            [[link name]] => [link name](/2021/07/11/link-name/)
    rx = r"\[\[([a-zA-Z0-9 .'=!-]+)\|?([a-zA-Z0-9 ]+)?\]\]"
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
    rx = r"```dot\n([\s\S]*)\n```"
    file_contents = replace(file_contents, rx => s -> dotsrc2imgsrc(match(rx, s)))
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

    index = """
    @def title = "Jason's Blog"

    # Archive

    """
    for p in posts
        index *= "- [$(p.title)]($(p.date)/$(escape_uri(p.name)))\n"
    end
    overwrite_if_diff!("index.md", index)
end

main()
