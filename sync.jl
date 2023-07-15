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
    io = IOBuffer()
    println(io, "+++")
    println(io, "title = \"", post.title, "\"")
    date = map(x -> parse(Int64, x), split(post.date, "/"))
    println(io, "date = Date(", join(date, ", "), ")")
    println(io, "hascode = true")
    println(io, "rss = \"", post.rss, "\"")
    println(io, "tags = ", post.tags)
    println(io, "+++")
    String(take!(io))
end

function remove_existing!()
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

function construct_data(posts_list)::Vector{Tuple{String, String, String}}
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

function copy_files!(data::Vector{Tuple{String, String, String}})
    for (src, dest, frontmatter) in data
        infile = open(src, "r")
        contents = read(infile, String)
        close(infile)

        processed = process_file(contents)

        make_space!(dest)
        outfile = open(dest, "w")
        write(outfile, frontmatter)
        write(outfile, processed)
        close(outfile)
        println("written ", dest)
    end
end

function main()
    println("syncing...")
    data::Vector{Tuple{String, String, String}} = construct_data(posts)
    for (src, _, _) in data
        if !isfile(src)
            println("not found: ", src)
            return 1
        end
    end
    remove_existing!()
    copy_files!(data)
end

main()
