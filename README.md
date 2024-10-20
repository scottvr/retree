# eert - inverse tree utility

This tool essentially inverts what /usr/bin/tree -F does. It creates a real directory structure on your filesystem based on an ascii line-art tree. 

## Why?
Let's say a README shows you a tree listing, suggesting you create the same. Or an architecture/requirements document does similarly. 

Or (as was my impetus for creating this) an LLM presents you with an example structure when you ask it to look at your code and suggest a sensible grouping of the classes within your single file into some number of separate files for packaging in a library you plan to make public. 

Sure, you could manually mkdir and touch files, or you could slowly watch it come into existence as you refactor your code into multiple directories and files, but if you're like me, you want to see it on your filesystem *now* and make changes and piecemeal refactor bits here and there, so you'd like to have the structure already exist, even as empty files. (And of course, the ability to use a source of truth diagram in the form of a text art directory tree without the potential for fatfingering or overlooking something when creating a real layout on a real filesystem is an obvious plus.)

## What? 
### Included is a Python tool that takes stdin and does the needful. for example 
```bash
git clone https://github.com/scottvr/eert/
cd eert/eert-python
# copy a structure (but not file contents) from some example directory:
tree -F /home/user/example | python eert.py
# or from a file copied from a chat, document, etc:
$ mkdir test && cd test
$ tree -F
./

0 directories, 0 files
$ python ../eert.py < ../example_tree.txt
$ tree -F
./
└── eert_example/
    ├── one/
    │   ├── 1file.py*
    │   ├── 2file.txt*
    │   └── 3file/
    ├── threedom/
    └── two/
        ├── blah.py*
        ├── bleh.py*
        └── somedir/

7 directories, 4 files
```

### Included also is a vscode extension that takes highlighted tree-format text, and creates a copy of the directory structure represented by it
see the eert-vscx/ subdirectory. It has yet to be packaged so if you want to run it, open extension.ts within vscode and press F5. I'll get around to bundling it up eventually.

Here's an example of usage within vscode :

![the last image from a series of five showing usage with the vscode extension](eert-vscx/docs/images/ss-5.png)

### Disclaimer
This is a utility made from desire and necessity to perform a specific purpose. Utilitarian. I likely would have kept it to myself except that once I spent the time to get it working within vscode, it occurred to me that I *might* not be the only person who has ever wished this to exist, so just in case, I thought I'd put this here for you. Point being, it is not whistles and bells, no command-line options or visual elements, etc. and probably never will have those things. (Unless a PR comes in with them showing that a) I am really not alone on this one and b) oh well, I guess again, I'm not alone.) 

If it remains forever minimalist, unseen and unused by anyone else, I am ok with that. I am quite accustomed to creating things for myself that apparently only I have any desire to exist. (See also my art, writing, music, etc.)

By me, for me, but happy to share.  
