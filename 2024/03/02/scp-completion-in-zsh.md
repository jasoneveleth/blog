+++
title = "How does `scp` completion work in zsh?"
date = Date("2024/03/02", "yyyy/mm/dd")
rss = "My attempt to understand the zsh completion system"
tags = String[]
descr = true
githubsource = "https://github.com/jasoneveleth/blog/blob/dev/2024/03/02/scp-completion-in-zsh.md"
+++
~~~
<details class="toc">
<summary>Table of Contents</summary>
~~~
\toc
~~~
</details>
~~~

Have you ever tried to complete a file on a remote server when you were `scp`-ing? 

```bash
$ scp user@server.com:/home/user/do|
downloads/    documents/
```

I have known for awhile that if you've set up ssh-keys or had a running ssh command open, that it would work. It'd been in the back of my mind to research, but I've never gotten around to it. That changed today.

My initial findings led me to [stack exchange](https://unix.stackexchange.com/questions/203931/whats-the-magic-that-allows-me-to-tab-complete-remote-files-as-i-type-an-scp-co). I'm 9 years late, but I figured I'd share some research I've done into this topic. You can ask zsh to give you the completion function for any command. So, to see for `scp`, you can use:

```bash
$ print $_comps[scp]
_ssh
```

From this, we learn that we're looking for `_ssh`. I did some looking into zsh source and I found this file: [`Completion/Unix/Command/_ssh`](https://github.com/zsh-users/zsh/blob/master/Completion/Unix/Command/_ssh). After poking around in here, it seems like the relevant parts are here (when it's completing the file part of the command):

```bash
    file)
      if compset -P 1 '[^./][^/]#:'; then
        _remote_files -- ssh ${(kv)~opt_args[(I)-[FP1246]]/-P/-p} && ret=0
      elif compset -P 1 '*@'; then
        suf=( -S '' )
        compset -S ':*' || suf=( -r: -S: )
        _wanted hosts expl 'remote host name' _ssh_hosts $suf && ret=0
      else
        _alternative \
            'files:: _files' \
            'hosts:remote host name:_ssh_hosts -r: -S:' \
            'users:user:_ssh_users -qS@' && ret=0
      fi
      ;;
```

Looking at the first if condition, we see that if the argument doesn't start with `./` or `/`, then we use `_remote_files` command. Doing some more digging, we can find that there is a corresponding file (`Completion/Unix/Type/_remote_files`). You can find it on your computer with: 

```bash
$ echo $functions_source[_remote_files]
/usr/share/zsh/5.9/functions/_remote_files
```

Here's an excerpt of header comment:

> Needs key-based authentication with no passwords or a running ssh-agent to work.

So, we do need to have an ssh session open. The file is just 104 lines long and pretty readable (if you're looked at zsh completion code before). The relevant line I didn't quite understand:

```
remfiles=(${(M)${(f)"$(
  _call_program files $cmd $cmd_args $host \
    command ls -d1FL -- "$rempat" 2>/dev/null
)"}%%[^/]#(|/)})
```

But after asking ChatGPT, the meat of the command is here: `$cmd $cmd_args $host command ls -d1FL -- "$rempat" 2>/dev/null`
Here, `$cmd` is `ssh`, so it's running `ls -d1FL -- $rempat` on the remote machine.

I patched the file to print out the actual command that it runs (unfortunately Apple doesn't like this, so I had to get around SIP, see the last section). Here is the command in all it's glory:

```bash
ssh -o BatchMode=yes -a -x jason@machine.example.com command ls -d1FL -- /home/jason/\*
```

This is the command that zsh is using to find files on remote machines.

# Breaking down the command

There's two parts to the command in the previous section. The part that gets executed on the remote machine: `command ls -d1FL -- /home/jason/\*` and the part that gives options to ssh: `ssh -o BatchMode=yes -a -x jason@machine.example.com`

Breaking down the remote command, we use `ls` with 
- `-d` to list directories as plain files (not their contents)
- `-1` for one file per line
- `-F` annotate directories with trailing `/`, and executables with `*`, etc
- `-L` for follow symbolic links to their final destination
- the `\*` is to stop the glob from being expanded on the local machine
- the `command` prefix is to ensure that we don't accidentally use an alias of `ls` on the remote machine

Breaking down the ssh options
- `-o BatchMode=yes` user interaction such as password prompts and host key confirmation requests will be disabled
- `-a` Disables forwarding of the authentication agent connection. (let's say 3 servers, `local -> A -> B`, this option means that you can't use your keys on `local` to connect to `B`. If you don't use `-a`, then when you are running commands on `A`, you could use your `local` keys to `ssh` from `A` to `B`)
- `-x` Disables X11 forwarding

# Getting around SIP

I first tried to edit `/usr/share/zsh/5.9/functions/_remote_files` directly. This didn't work obviously because my user isn't root. I tried `sudo vim`, but that didn't work either. So (and I know this is bad) I tried `sudo sh` and then `vim`. This also didn't work. I realized that SIP was what was preventing me.

So, I unloaded the function and loaded my patch:

```bash
unfunction _remote_files
autoload -U /tmp/_remote_files
```

{{ addcomments }}
