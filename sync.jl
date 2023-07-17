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
    Post("bayes rule", "2023/07/17", ["math"], "", "Bayes' Rule (in real life)"),
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
        dest = p.date * "/" * fuckwith(p.name) * ".md"
        push!(ret, (src, dest, frontmatter(p)))
    end
    ret
end

function fuckwith(str)
    URIs.escapeuri(replace(str, " " => "-"))
end

function process_file(s)
    function f(x)
        SubstitutionString("[$(x)](/2021/07/11/$(fuckwith(x)))")
    end
    # we can't use replace(s, regex => substituionstr ) because we 
    # need the capture group to be evaluated before we URI encode it
    # this function assumes that we are returning a substitution string
    # so there's no way to arrange the computation such that the URI encode 
    # happens after the capture
    replace(s, r"\[\[([a-zA-Z0-9 .'-=!]*)\]\]" => f(s"\1"))
end

function make_space!(file_path)
    directory_path = dirname(file_path)
    mkpath(directory_path)
end

function make_contents(note_contents, frontmatter)
    """
    $(frontmatter)$(process_file(note_contents))
    {{ addcomments }}
    """
end

function copy_files!(data::Vector{Tuple{String, String, String}})
    for (src, dest, frontmatter) in data
        newcontent = make_contents(read(src, String), frontmatter)

        make_space!(dest)
        if isfile(dest) && read(dest, String) == newcontent
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
