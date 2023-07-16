import URIs
import Base.Filesystem

struct Post
    name::String
    date::String
    tags::Vector{String}
    rss::String
    title::String
end

const posts = [
    Post("five color theorem",  "2021/07/16", ["math"], "The Five Color Theorem asserts that no planar graphs are 5-colorable.", "Five Color Theorem"),
    Post("linear regression", "2021/07/11", ["math"], "", "Linear Regression"),
    Post("picks theorem", "2021/09/03", ["math"], "Pick's Theorem is a formula for the area of a closed polygon with integer vertices.", "Pick's Theorem"),
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

function remove_existing!()
    # all years are 20xx
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

function filepaths_and_frontmatter(posts_list)::Vector{Tuple{String, String, String}}
    ret = []
    for p in posts_list
        src = notes_dir * p.name * ".md"
        dest = p.date * "/" * URIs.escapeuri(replace(p.name, " " => "-")) * ".md"
        push!(ret, (src, dest, frontmatter(p)))
    end
    ret
end

function process_file(s)
    s
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
        oldcontent = read(dest, String)
        if cmp(oldcontent, newcontent) == 0
            println("skipped: ", dest)
        else
            write(dest, newcontent)
            println("written ", dest)
        end
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
end

main()
